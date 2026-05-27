import 'dart:async';

import 'errors.dart';
import 'models/episode.dart';
import 'models/site.dart';
import 'models/work.dart';
import 'models/work_id.dart';
import 'models/work_query.dart';
import 'novel_repository.dart';

/// In-memory `NovelRepository` for tests and developer debug menus.
///
/// Seed it with a map of `WorkId → (Work, episodes, bodies)` and it
/// will reply deterministically. Optional [artificialLatency] lets
/// tests verify progressive streaming and rate-limit interactions.
class FakeNovelRepository implements NovelRepository {
  FakeNovelRepository({
    required this.site,
    Map<WorkId, FakeWorkData>? seed,
    this.artificialLatency = Duration.zero,
  }) : _data = <WorkId, FakeWorkData>{...?seed};

  @override
  final Site site;

  final Map<WorkId, FakeWorkData> _data;

  /// Synthetic delay applied to each fetch operation so tests can
  /// observe streaming behavior. Defaults to zero (instant).
  final Duration artificialLatency;

  /// Add or replace a work's data. Useful for tests that mutate
  /// state mid-flow.
  void put(WorkId id, FakeWorkData data) {
    _data[id] = data;
  }

  /// Visible state for assertions.
  Map<WorkId, FakeWorkData> get dataForTest =>
      Map<WorkId, FakeWorkData>.unmodifiable(_data);

  @override
  Future<List<Work>> searchWorks(WorkQuery query) async {
    await _sleep();
    Iterable<Work> matches = _data.values
        .where((FakeWorkData d) => d.work.id.site == query.site)
        .map((FakeWorkData d) => d.work);
    if (query.keyword != null && query.keyword!.isNotEmpty) {
      final String k = query.keyword!.toLowerCase();
      matches = matches.where(
        (Work w) =>
            w.title.toLowerCase().contains(k) ||
            w.author.toLowerCase().contains(k),
      );
    }
    return matches.skip(query.offset).take(query.limit).toList();
  }

  @override
  Future<Work> fetchWork(WorkId id) async {
    await _sleep();
    final FakeWorkData? d = _data[id];
    if (d == null) {
      throw WorkNotFoundError(
        'FakeNovelRepository: $id not seeded',
        workId: id,
      );
    }
    return d.work;
  }

  @override
  Stream<Episode> fetchEpisodes(WorkId workId) async* {
    final FakeWorkData? d = _data[workId];
    if (d == null) {
      throw WorkNotFoundError(
        'FakeNovelRepository: $workId not seeded',
        workId: workId,
      );
    }
    for (final Episode ep in d.episodes) {
      await _sleep();
      yield ep;
    }
  }

  @override
  Future<EpisodeBody> fetchEpisodeBody(
    WorkId workId,
    EpisodeId episodeId,
  ) async {
    await _sleep();
    final FakeWorkData? d = _data[workId];
    if (d == null) {
      throw WorkNotFoundError(
        'FakeNovelRepository: $workId not seeded',
        workId: workId,
      );
    }
    final EpisodeBody? body = d.bodies[episodeId.index];
    if (body == null) {
      throw EpisodeNotFoundError(
        'FakeNovelRepository: episode ${episodeId.index} not seeded',
        workId: workId,
        episodeIndex: episodeId.index,
      );
    }
    return body;
  }

  Future<void> _sleep() async {
    if (artificialLatency > Duration.zero) {
      await Future<void>.delayed(artificialLatency);
    }
  }
}

/// Convenience container used by [FakeNovelRepository.seed]. `bodies`
/// is keyed by 1-based episode index.
class FakeWorkData {
  const FakeWorkData({
    required this.work,
    required this.episodes,
    required this.bodies,
  });

  final Work work;
  final List<Episode> episodes;
  final Map<int, EpisodeBody> bodies;
}
