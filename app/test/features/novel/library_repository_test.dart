import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/media_session.dart';
import 'package:geekplayer/core/novel/errors.dart';
import 'package:geekplayer/core/novel/fake_novel_repository.dart';
import 'package:geekplayer/core/novel/models/episode.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work.dart';
import 'package:geekplayer/core/novel/models/work_id.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/novel/data/consent_guarded_repository.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';
import 'package:geekplayer/features/novel/data/library_repository.dart';

FakeWorkData _fakeData({required WorkId workId, required int episodeCount}) {
  final DateTime now = DateTime.utc(2026, 5, 27);
  final List<Episode> eps = <Episode>[
    for (int i = 1; i <= episodeCount; i++)
      Episode(id: EpisodeId(i), title: 'ep$i'),
  ];
  final Map<int, EpisodeBody> bodies = <int, EpisodeBody>{
    for (int i = 1; i <= episodeCount; i++)
      i: EpisodeBody(body: 'body-$i', fetchedAt: now),
  };
  return FakeWorkData(
    work: Work(
      id: workId,
      title: 'title',
      author: 'author',
      episodeCount: episodeCount,
      addedAt: now,
    ),
    episodes: eps,
    bodies: bodies,
  );
}

void main() {
  late AppDatabase db;
  late LibraryRepository library;
  late FakeNovelRepository source;

  const WorkId workId = WorkId(site: Site.narou, externalId: 'n1');

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    library = LibraryRepository(
      worksDao: db.novelWorksDao,
      episodesDao: db.novelEpisodesDao,
      bookmarksDao: db.novelBookmarksDao,
    );
    source = FakeNovelRepository(
      site: Site.narou,
      seed: <WorkId, FakeWorkData>{
        workId: _fakeData(workId: workId, episodeCount: 3),
      },
    );
  });

  tearDown(() => db.close());

  test('addToLibrary writes work + all episodes (active caching)', () async {
    await library.addToLibrary(source, workId);

    final Work? w = await library.getWork(workId);
    expect(w, isNotNull);
    expect(w!.title, 'title');

    final List<NovelEpisodeRow> eps = await library.listEpisodes(workId);
    expect(eps.length, 3);
    expect(eps.map((NovelEpisodeRow r) => r.episodeIndex).toList(), <int>[
      1,
      2,
      3,
    ]);
    expect(eps.first.body, 'body-1');
  });

  test(
    'browsing alone (fetchEpisodeBody) does not write to novel_episodes',
    () async {
      // Pure call against the source — no LibraryRepository involvement.
      await source.fetchEpisodeBody(workId, EpisodeId(1));
      final List<NovelEpisodeRow> rows = await library.listEpisodes(workId);
      expect(rows, isEmpty);
      expect(await library.getWork(workId), isNull);
    },
  );

  test(
    'addToLibrary is idempotent: re-running does not duplicate rows',
    () async {
      await library.addToLibrary(source, workId);
      await library.addToLibrary(source, workId);
      expect((await library.listEpisodes(workId)).length, 3);
    },
  );

  test('removeFromLibrary cascades to episodes and bookmark', () async {
    await library.addToLibrary(source, workId);
    await library.saveBookmark(
      workId,
      PagePosition(pageIndex: 2, scrollFraction: 0.5),
    );

    await library.removeFromLibrary(workId);

    expect(await library.getWork(workId), isNull);
    expect(await library.listEpisodes(workId), isEmpty);
    expect(await library.getBookmark(workId), isNull);
  });

  test('saveBookmark / getBookmark round-trip', () async {
    await library.addToLibrary(source, workId);

    expect(await library.getBookmark(workId), isNull);

    await library.saveBookmark(
      workId,
      PagePosition(pageIndex: 3, scrollFraction: 0.42),
    );

    final PagePosition? p = await library.getBookmark(workId);
    expect(p, isNotNull);
    expect(p!.pageIndex, 3);
    expect(p.scrollFraction, closeTo(0.42, 1e-9));
  });

  test('listLibrary filters by site', () async {
    await library.addToLibrary(source, workId);

    const WorkId other = WorkId(site: Site.kakuyomu, externalId: 'k1');
    final FakeNovelRepository kakSource = FakeNovelRepository(
      site: Site.kakuyomu,
      seed: <WorkId, FakeWorkData>{
        other: _fakeData(workId: other, episodeCount: 1),
      },
    );
    await library.addToLibrary(kakSource, other);

    expect((await library.listLibrary()).length, 2);
    expect((await library.listLibrary(site: Site.narou)).length, 1);
    expect((await library.listLibrary(site: Site.kakuyomu)).length, 1);
  });

  test('source.site != workId.site is rejected', () async {
    const WorkId kakWorkId = WorkId(
      site: Site.kakuyomu,
      externalId: 'mismatched',
    );
    await expectLater(
      library.addToLibrary(source, kakWorkId),
      throwsArgumentError,
    );
  });

  test('consent-guarded source propagates SiteConsentRequiredError', () async {
    final ConsentRepository consent = ConsentRepository(db.siteConsentsDao);
    final ConsentGuardedRepository guarded = ConsentGuardedRepository(
      inner: source,
      consent: consent,
    );

    // No consent row -> first internal source call fails.
    await expectLater(
      library.addToLibrary(guarded, workId),
      throwsA(isA<SiteConsentRequiredError>()),
    );

    // Grant + retry succeeds.
    await consent.grant(Site.narou);
    await library.addToLibrary(guarded, workId);
    expect((await library.listEpisodes(workId)).length, 3);
  });
}
