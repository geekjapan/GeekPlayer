import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/episode.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work.dart';
import 'package:geekplayer/core/novel/models/work_id.dart';
import 'package:geekplayer/core/novel/models/work_query.dart';
import 'package:geekplayer/core/novel/novel_repository.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/novel/data/library_repository.dart';

/// `NovelRepository` mock that fails [fetchEpisodeBody] for any
/// episode index in [failOn] (with [Exception]). All other calls
/// succeed deterministically.
class _FlakyRepo implements NovelRepository {
  _FlakyRepo({required this.totalEpisodes, required this.failOn});

  @override
  final Site site = Site.narou;

  final int totalEpisodes;
  Set<int> failOn;
  final List<int> bodyCalls = <int>[];
  final Work _work = Work(
    id: const WorkId(site: Site.narou, externalId: 'flaky'),
    title: 'flaky',
    author: 'a',
    episodeCount: 10,
    addedAt: DateTime.utc(2026, 5, 27),
  );

  @override
  Future<Work> fetchWork(WorkId id) async => _work;

  @override
  Stream<Episode> fetchEpisodes(WorkId workId) async* {
    for (int i = 1; i <= totalEpisodes; i++) {
      yield Episode(id: EpisodeId(i), title: 'e$i');
    }
  }

  @override
  Future<EpisodeBody> fetchEpisodeBody(
    WorkId workId,
    EpisodeId episodeId,
  ) async {
    bodyCalls.add(episodeId.index);
    if (failOn.contains(episodeId.index)) {
      throw Exception('simulated failure for episode ${episodeId.index}');
    }
    return EpisodeBody(
      body: 'body-${episodeId.index}',
      fetchedAt: DateTime.utc(2026, 5, 27),
    );
  }

  @override
  Future<List<Work>> searchWorks(WorkQuery query) async => <Work>[_work];
}

void main() {
  test('10 episodes, fail on #5: second run fetches only 5..10', () async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);

    final LibraryRepository library = LibraryRepository(
      worksDao: db.novelWorksDao,
      episodesDao: db.novelEpisodesDao,
      bookmarksDao: db.novelBookmarksDao,
    );
    final _FlakyRepo repo = _FlakyRepo(totalEpisodes: 10, failOn: <int>{5});
    const WorkId workId = WorkId(site: Site.narou, externalId: 'flaky');

    // First run aborts on episode 5.
    await expectLater(
      library.addToLibrary(repo, workId),
      throwsA(isA<Exception>()),
    );
    expect(repo.bodyCalls, <int>[1, 2, 3, 4, 5]);
    expect(
      (await library.listEpisodes(
        workId,
      )).map((NovelEpisodeRow r) => r.episodeIndex).toList(),
      <int>[1, 2, 3, 4],
    );

    // Second run with failure cleared — must skip 1..4 and call
    // bodies only for 5..10 (resume contract from spec
    // "Resume partial Library add").
    repo.bodyCalls.clear();
    repo.failOn = <int>{};
    await library.addToLibrary(repo, workId);

    expect(repo.bodyCalls, <int>[5, 6, 7, 8, 9, 10]);
    expect(
      (await library.listEpisodes(
        workId,
      )).map((NovelEpisodeRow r) => r.episodeIndex).toList(),
      <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    );
  });

  test('progress callback reports cumulative fetched / total counts', () async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);

    final LibraryRepository library = LibraryRepository(
      worksDao: db.novelWorksDao,
      episodesDao: db.novelEpisodesDao,
      bookmarksDao: db.novelBookmarksDao,
    );
    final _FlakyRepo repo = _FlakyRepo(totalEpisodes: 3, failOn: <int>{});
    const WorkId workId = WorkId(site: Site.narou, externalId: 'flaky');

    final List<List<int>> progress = <List<int>>[];
    await library.addToLibrary(
      repo,
      workId,
      onProgress: (int fetched, int total) =>
          progress.add(<int>[fetched, total]),
    );
    // `total` reflects Work.episodeCount (10), not what the stream
    // emits — Work.episodeCount is what the site reports.
    expect(progress, <List<int>>[
      <int>[1, 10],
      <int>[2, 10],
      <int>[3, 10],
    ]);
  });
}
