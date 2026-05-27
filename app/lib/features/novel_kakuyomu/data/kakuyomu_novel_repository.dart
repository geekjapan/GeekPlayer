import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/novel/errors.dart';
import '../../../core/novel/models/episode.dart' as core;
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart' as core;
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/models/work_query.dart';
import '../../../core/novel/novel_repository.dart';
import '../../novel/data/consent_repository.dart';
import '../domain/kakuyomu_episode.dart';
import '../domain/kakuyomu_feed_item.dart';
import '../domain/kakuyomu_search_query.dart';
import '../domain/kakuyomu_work.dart';
import 'kakuyomu_html_source.dart';
import 'kakuyomu_rss_source.dart';

/// Composite [NovelRepository] for Kakuyomu.
///
/// Splits responsibility across two collaborators:
///   - [KakuyomuRssSource] for search / latest / ranking / updates
///   - [KakuyomuHtmlSource] for work-detail + episode body
///
/// Every public method short-circuits via [ConsentRepository] before
/// any HTTP request fires — matching the
/// `kakuyomu-novel-source / Consent denied short-circuits` scenario.
///
/// Active caching contract (per ADR-0001): this repository NEVER
/// writes to local storage. Persistence happens only inside
/// `LibraryRepository.addToLibrary`, which consumes our streaming
/// [fetchEpisodes] + [fetchEpisodeBody] outputs.
final class KakuyomuNovelRepository implements NovelRepository {
  KakuyomuNovelRepository({
    required this.rssSource,
    required this.htmlSource,
    required this.consent,
    CancelToken? cancelToken,
  }) : _cancelToken = cancelToken; // ignore: prefer_initializing_formals

  final KakuyomuRssSource rssSource;
  final KakuyomuHtmlSource htmlSource;
  final ConsentRepository consent;
  final CancelToken? _cancelToken;

  @override
  Site get site => Site.kakuyomu;

  Future<void> _assertConsent() async {
    if (!await consent.hasFreshConsent(Site.kakuyomu)) {
      throw const SiteConsentRequiredError(
        'kakuyomu site consent required',
        site: Site.kakuyomu,
      );
    }
  }

  /// Kakuyomu-specific: keyword + sort search returning normalized
  /// feed items (not full work objects, since RSS doesn't carry
  /// episode counts).
  Future<List<KakuyomuFeedItem>> search(KakuyomuSearchQuery query) async {
    await _assertConsent();
    return rssSource.search(query);
  }

  /// Kakuyomu-specific: newest published feed.
  Future<List<KakuyomuFeedItem>> latest() async {
    await _assertConsent();
    return rssSource.latest();
  }

  /// Kakuyomu-specific: ranking feed.
  Future<List<KakuyomuFeedItem>> ranking(KakuyomuRankingPeriod period) async {
    await _assertConsent();
    return rssSource.ranking(period);
  }

  /// Kakuyomu-specific: full work detail (with all episode metadata).
  Future<KakuyomuWorkDetail> fetchWorkDetail(String workId) async {
    await _assertConsent();
    return htmlSource.fetchWork(workId, cancelToken: _cancelToken);
  }

  /// Kakuyomu-specific: full body for a single episode.
  Future<KakuyomuEpisodeBody> fetchEpisodeFullBody(
    String workId,
    String episodeId,
  ) async {
    await _assertConsent();
    return htmlSource.fetchEpisodeBody(
      workId,
      episodeId,
      cancelToken: _cancelToken,
    );
  }

  // ---------------------------------------------------------------
  // NovelRepository interface mapping.
  // ---------------------------------------------------------------

  @override
  Future<List<core.Work>> searchWorks(WorkQuery query) async {
    await _assertConsent();
    if (query.site != Site.kakuyomu) return const <core.Work>[];
    final KakuyomuSearchQuery kq = KakuyomuSearchQuery(
      keyword: query.keyword ?? '',
    );
    final List<KakuyomuFeedItem> items = await rssSource.search(kq);
    final DateTime now = DateTime.now().toUtc();
    final List<core.Work> out = <core.Work>[];
    for (final KakuyomuFeedItem it in items) {
      if (it.workId.isEmpty) continue;
      out.add(
        core.Work(
          id: WorkId(site: Site.kakuyomu, externalId: it.workId),
          title: it.title,
          author: it.author ?? '',
          synopsis: it.summary,
          episodeCount: 0, // not known from RSS — filled in by fetchWork
          addedAt: now,
        ),
      );
    }
    return out;
  }

  @override
  Future<core.Work> fetchWork(WorkId id) async {
    if (id.site != Site.kakuyomu) {
      throw ArgumentError.value(id, 'id', 'expected Site.kakuyomu');
    }
    final KakuyomuWorkDetail d = await fetchWorkDetail(id.externalId);
    return core.Work(
      id: id,
      title: d.title,
      author: d.author,
      synopsis: d.synopsis,
      episodeCount: d.episodes.length,
      addedAt: DateTime.now().toUtc(),
      lastSyncedAt: d.lastUpdatedAt,
    );
  }

  @override
  Stream<core.Episode> fetchEpisodes(WorkId workId) async* {
    if (workId.site != Site.kakuyomu) {
      throw ArgumentError.value(workId, 'workId', 'expected Site.kakuyomu');
    }
    await _assertConsent();
    final KakuyomuWorkDetail d = await fetchWorkDetail(workId.externalId);
    for (int i = 0; i < d.episodes.length; i++) {
      yield core.Episode(
        id: core.EpisodeId(i + 1),
        title: d.episodes[i].title,
      );
    }
  }

  @override
  Future<core.EpisodeBody> fetchEpisodeBody(
    WorkId workId,
    core.EpisodeId episodeId,
  ) async {
    if (workId.site != Site.kakuyomu) {
      throw ArgumentError.value(workId, 'workId', 'expected Site.kakuyomu');
    }
    await _assertConsent();
    // Map the 1-based [episodeId.index] back to the Kakuyomu
    // numeric episode id by re-fetching the work detail. (For the
    // streaming API this is paid once per Library-add.)
    final KakuyomuWorkDetail d = await fetchWorkDetail(workId.externalId);
    final int idx = episodeId.index - 1;
    if (idx < 0 || idx >= d.episodes.length) {
      throw EpisodeNotFoundError(
        'episode ${episodeId.index} not found for ${workId.externalId}',
        workId: workId,
        episodeIndex: episodeId.index,
      );
    }
    final KakuyomuEpisodeBody body =
        await fetchEpisodeFullBody(workId.externalId, d.episodes[idx].id);
    return core.EpisodeBody(
      body: body.toPlainText(),
      fetchedAt: DateTime.now().toUtc(),
    );
  }
}
