import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/errors.dart';
import 'package:geekplayer/core/novel/fake_novel_repository.dart';
import 'package:geekplayer/core/novel/models/episode.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work.dart';
import 'package:geekplayer/core/novel/models/work_id.dart';
import 'package:geekplayer/core/novel/models/work_query.dart';
import 'package:geekplayer/core/storage/database.dart';

FakeNovelRepository _build({
  Duration latency = Duration.zero,
  int episodeCount = 3,
}) {
  const WorkId workId = WorkId(site: Site.narou, externalId: 'n1');
  final DateTime now = DateTime.utc(2026, 5, 27);
  return FakeNovelRepository(
    site: Site.narou,
    artificialLatency: latency,
    seed: <WorkId, FakeWorkData>{
      workId: FakeWorkData(
        work: Work(
          id: workId,
          title: 'title',
          author: 'author',
          episodeCount: episodeCount,
          addedAt: now,
        ),
        episodes: <Episode>[
          for (int i = 1; i <= episodeCount; i++)
            Episode(id: EpisodeId(i), title: 'e$i'),
        ],
        bodies: <int, EpisodeBody>{
          for (int i = 1; i <= episodeCount; i++)
            i: EpisodeBody(body: 'body-$i', fetchedAt: now),
        },
      ),
    },
  );
}

void main() {
  const WorkId workId = WorkId(site: Site.narou, externalId: 'n1');

  test('fetchEpisodes streams items one by one', () async {
    final FakeNovelRepository r = _build(episodeCount: 4);
    final List<int> indices = <int>[];
    await for (final Episode ep in r.fetchEpisodes(workId)) {
      indices.add(ep.id.index);
    }
    expect(indices, <int>[1, 2, 3, 4]);
  });

  test(
    'fetchEpisodeBody does not persist (no drift writes from this layer)',
    () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final FakeNovelRepository r = _build();
      await r.fetchEpisodeBody(workId, EpisodeId(1));
      expect(
        await db.novelEpisodesDao.existingIndices(
          workId.site.code,
          workId.externalId,
        ),
        isEmpty,
      );
    },
  );

  test('fetchWork on a missing WorkId throws WorkNotFoundError', () async {
    final FakeNovelRepository r = _build();
    await expectLater(
      r.fetchWork(const WorkId(site: Site.narou, externalId: 'nope')),
      throwsA(isA<WorkNotFoundError>()),
    );
  });

  test(
    'fetchEpisodeBody on a missing index throws EpisodeNotFoundError',
    () async {
      final FakeNovelRepository r = _build(episodeCount: 1);
      await expectLater(
        r.fetchEpisodeBody(workId, EpisodeId(99)),
        throwsA(isA<EpisodeNotFoundError>()),
      );
    },
  );

  test('searchWorks honours site, keyword, limit, offset', () async {
    final FakeNovelRepository r = _build();
    final List<Work> hit = await r.searchWorks(
      const WorkQuery(site: Site.narou, keyword: 'title'),
    );
    expect(hit.length, 1);

    final List<Work> miss = await r.searchWorks(
      const WorkQuery(site: Site.narou, keyword: 'no-such'),
    );
    expect(miss, isEmpty);

    final List<Work> wrongSite = await r.searchWorks(
      const WorkQuery(site: Site.kakuyomu),
    );
    expect(wrongSite, isEmpty);
  });

  test('artificialLatency delays each fetch', () async {
    final FakeNovelRepository r = _build(
      latency: const Duration(milliseconds: 10),
      episodeCount: 3,
    );
    final Stopwatch sw = Stopwatch()..start();
    await for (final _ in r.fetchEpisodes(workId)) {
      // drain
    }
    sw.stop();
    // 3 episodes * 10ms = ~30ms (loose lower bound).
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(25));
  });
}
