import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/media/media_session.dart';
import '../../../core/novel/models/episode.dart';
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/novel_repository.dart';
import '../../../core/storage/database.dart';
import '../../../core/storage/providers.dart';

part 'library_repository.g.dart';

/// Drift-backed implementation of the "user's online novel Library".
///
/// Glues the site-agnostic [NovelRepository] interface to the
/// `novel_works` / `novel_episodes` / `novel_bookmarks` tables. The
/// rule from design.md D3 / spec `online-novel-library` "Library add
/// flow (active caching)" — "passive caching MUST NOT occur" — is
/// enforced here: persistence happens only inside [addToLibrary] /
/// [saveBookmark] / [removeFromLibrary].
///
/// Idempotency / resume (spec scenario "Resume partial Library add"):
/// before fetching episode bodies, [addToLibrary] reads
/// [NovelEpisodesDao.existingIndices] and only calls
/// [NovelRepository.fetchEpisodeBody] for missing indices.
class LibraryRepository {
  LibraryRepository({
    required NovelWorksDao worksDao,
    required NovelEpisodesDao episodesDao,
    required NovelBookmarksDao bookmarksDao,
  }) : _worksDao = worksDao, // ignore: prefer_initializing_formals
       _episodesDao = episodesDao, // ignore: prefer_initializing_formals
       _bookmarksDao = bookmarksDao; // ignore: prefer_initializing_formals

  final NovelWorksDao _worksDao;
  final NovelEpisodesDao _episodesDao;
  final NovelBookmarksDao _bookmarksDao;

  /// Add [workId] (fetched via [source]) to the Library. Idempotent:
  /// rows already present in `novel_episodes` are NOT re-fetched.
  ///
  /// Each successfully fetched episode is persisted immediately
  /// (single-row upsert), so a mid-flow failure leaves earlier
  /// progress intact and a re-run picks up where it left off.
  Future<void> addToLibrary(
    NovelRepository source,
    WorkId workId, {
    void Function(int fetched, int total)? onProgress,
  }) async {
    if (source.site != workId.site) {
      throw ArgumentError(
        'LibraryRepository.addToLibrary: source.site=${source.site.code} '
        'does not match workId.site=${workId.site.code}',
      );
    }
    final Work work = await source.fetchWork(workId);

    await _worksDao.upsertWork(
      site: workId.site.code,
      externalId: workId.externalId,
      title: work.title,
      author: work.author,
      synopsis: work.synopsis,
      episodeCount: work.episodeCount,
      addedAt: work.addedAt,
      lastSyncedAt: DateTime.now().toUtc(),
    );

    final Set<int> existing = await _episodesDao.existingIndices(
      workId.site.code,
      workId.externalId,
    );

    // We rely on fetchEpisodes streaming order to know episode titles
    // alongside their indices. If an index is already cached we still
    // need its title from the stream for free, but we skip the body
    // fetch + write to honour the resume contract.
    int seen = existing.length;
    await for (final Episode ep in source.fetchEpisodes(workId)) {
      final int idx = ep.id.index;
      if (existing.contains(idx)) continue;
      final EpisodeBody body = await source.fetchEpisodeBody(workId, ep.id);
      await _episodesDao.upsertEpisode(
        site: workId.site.code,
        externalId: workId.externalId,
        episodeIndex: idx,
        title: ep.title,
        body: body.body,
        fetchedAt: body.fetchedAt,
      );
      seen += 1;
      onProgress?.call(seen, work.episodeCount);
    }
  }

  /// Cascade-delete [workId] from `novel_works`, `novel_episodes`, and
  /// `novel_bookmarks` (single transaction — see
  /// [NovelWorksDao.deleteWork]).
  Future<void> removeFromLibrary(WorkId workId) {
    return _worksDao.deleteWork(workId.site.code, workId.externalId);
  }

  /// Return all Library entries newest-first (by `addedAt`).
  Future<List<Work>> listLibrary({Site? site}) async {
    final List<NovelWorkRow> rows = site == null
        ? await _worksDao.listAll()
        : await _worksDao.listBySite(site.code);
    return rows.map(_rowToWork).toList();
  }

  Future<Work?> getWork(WorkId workId) async {
    final NovelWorkRow? row = await _worksDao.getWork(
      workId.site.code,
      workId.externalId,
    );
    if (row == null) return null;
    return _rowToWork(row);
  }

  /// Return the cached bookmark for [workId], or `null` if none
  /// exists. The reader screen uses this on open to resume.
  Future<PagePosition?> getBookmark(WorkId workId) async {
    final NovelBookmarkRow? row = await _bookmarksDao.getBookmark(
      workId.site.code,
      workId.externalId,
    );
    if (row == null) return null;
    return PagePosition(
      pageIndex: row.episodeIndex,
      scrollFraction: row.scrollFraction,
    );
  }

  /// Upsert the bookmark for [workId]. Called by the reader's debounced
  /// scroll listener (spec scenario "Bookmark debounces during
  /// continuous scroll").
  Future<void> saveBookmark(WorkId workId, PagePosition position) {
    return _bookmarksDao.upsertBookmark(
      site: workId.site.code,
      externalId: workId.externalId,
      episodeIndex: position.pageIndex,
      scrollFraction: position.scrollFraction,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Return cached episodes for [workId] in `episodeIndex` order.
  Future<List<NovelEpisodeRow>> listEpisodes(WorkId workId) {
    return _episodesDao.listEpisodes(workId.site.code, workId.externalId);
  }

  Work _rowToWork(NovelWorkRow row) {
    final Site? site = Site.fromCode(row.site);
    return Work(
      id: WorkId(site: site ?? Site.narou, externalId: row.externalId),
      title: row.title,
      author: row.author,
      synopsis: row.synopsis,
      episodeCount: row.episodeCount,
      addedAt: row.addedAt,
      lastSyncedAt: row.lastSyncedAt,
    );
  }
}

@Riverpod(keepAlive: true)
LibraryRepository libraryRepository(Ref ref) {
  return LibraryRepository(
    worksDao: ref.watch(novelWorksDaoProvider),
    episodesDao: ref.watch(novelEpisodesDaoProvider),
    bookmarksDao: ref.watch(novelBookmarksDaoProvider),
  );
}
