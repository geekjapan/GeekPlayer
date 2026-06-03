import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'migrations/v2_to_v3.dart';
import 'migrations/v3_to_v4.dart';
import 'migrations/v4_to_v5.dart';
import 'migrations/v5_to_v6.dart';
import 'tables/app_settings.dart';
import 'tables/book_bookmarks.dart';
import 'tables/book_metadata.dart';
import 'tables/favorites.dart';
import 'tables/manga_bookmarks.dart';
import 'tables/manga_metadata.dart';
import 'tables/media_index.dart';
import 'tables/novel_bookmarks.dart';
import 'tables/novel_episodes.dart';
import 'tables/novel_works.dart';
import 'tables/playback_positions.dart';
import 'tables/playlist_items.dart';
import 'tables/playlists.dart';
import 'tables/recent_items.dart';
import 'tables/site_consents.dart';
import 'tables/watch_history.dart';

part 'database.g.dart';

/// Recent-items list cap from spec L1 R4. See design.md Q-D1.
const int kRecentItemsCap = 50;

/// Single drift database for GeekPlayer.
///
/// Schema lineage (see CONVENTIONS.md §5):
///   - v1 — `add-local-video-playback`: playback_positions + recent_items
///   - v2 — `add-online-novel-library`: novel_works, novel_episodes,
///          novel_bookmarks, site_consents
///   - v3 — `add-app-settings`: app_settings
///   - v4 — `add-pdf-epub-reader`: book_metadata, book_bookmarks
///   - v5 — `add-manga-zip-viewer`: manga_metadata, manga_bookmarks
///   - v6 — `add-media-library`: media_index, watch_history, favorites,
///          playlists, playlist_items
@DriftDatabase(
  tables: <Type>[
    PlaybackPositions,
    RecentItems,
    NovelWorks,
    NovelEpisodes,
    NovelBookmarks,
    SiteConsents,
    AppSettings,
    BookMetadata,
    BookBookmarks,
    MangaMetadata,
    MangaBookmarks,
    MediaIndex,
    WatchHistory,
    Favorites,
    Playlists,
    PlaylistItems,
  ],
  daos: <Type>[
    PlaybackPositionsDao,
    RecentItemsDao,
    NovelWorksDao,
    NovelEpisodesDao,
    NovelBookmarksDao,
    SiteConsentsDao,
    AppSettingsDao,
    BookMetadataDao,
    BookBookmarksDao,
    MangaMetadataDao,
    MangaBookmarksDao,
    MediaIndexDao,
    WatchHistoryDao,
    FavoritesDao,
    PlaylistsDao,
    PlaylistItemsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for tests: pass an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // v1 -> v2: introduce novel_* tables + site_consents.
      // Existing playback_positions / recent_items rows are preserved
      // (drift `createTable` is additive). Migration test in
      // app/test/core/storage/migration_v1_to_v2_test.dart verifies that.
      if (from < 2) {
        await m.createTable(novelWorks);
        await m.createTable(novelEpisodes);
        await m.createTable(novelBookmarks);
        await m.createTable(siteConsents);
      }
      // v2 -> v3: introduce app_settings (EAV). Additive only — every
      // earlier table is preserved. See
      // app/test/core/storage/migration_v2_to_v3_test.dart and
      // app/lib/core/storage/migrations/v2_to_v3.dart for the migration
      // logic and skip-migration coverage (v1 -> v3).
      if (from < 3) {
        await migrateV2ToV3(m, appSettings);
      }
      // v3 -> v4: introduce book_metadata + book_bookmarks. Additive only.
      // See app/test/core/storage/migration_v3_to_v4_test.dart and
      // app/lib/core/storage/migrations/v3_to_v4.dart.
      if (from < 4) {
        await migrateV3ToV4(m, bookMetadata, bookBookmarks);
      }
      // v4 -> v5: introduce manga_metadata + manga_bookmarks. Additive only.
      // See app/test/core/storage/migration_v4_to_v5_test.dart and
      // app/lib/core/storage/migrations/v4_to_v5.dart.
      if (from < 5) {
        await migrateV4ToV5(m, mangaMetadata, mangaBookmarks);
      }
      // v5 -> v6: introduce media_index, watch_history, favorites, playlists,
      // playlist_items. Additive only.
      // See app/test/core/storage/migration_v5_to_v6_test.dart and
      // app/lib/core/storage/migrations/v5_to_v6.dart.
      if (from < 6) {
        await migrateV5ToV6(
          m,
          mediaIndex,
          watchHistory,
          favorites,
          playlists,
          playlistItems,
        );
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'geekplayer');
}

/// DAO for [PlaybackPositions]. Provides upsert and lookup keyed by the
/// normalized file URI of an Episode.
@DriftAccessor(tables: <Type>[PlaybackPositions])
class PlaybackPositionsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaybackPositionsDaoMixin {
  PlaybackPositionsDao(super.db);

  /// Insert or replace the row for [uri] with [position]. `updatedAt` is
  /// stamped with the wall clock.
  Future<void> upsert(String uri, Duration position) {
    return into(playbackPositions).insertOnConflictUpdate(
      PlaybackPositionsCompanion.insert(
        uri: uri,
        positionMs: position.inMilliseconds,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Return the saved [Duration] for [uri], or `null` if none exists.
  Future<Duration?> getByUri(String uri) async {
    final PlaybackPositionRow? row =
        await (select(playbackPositions)
              ..where(($PlaybackPositionsTable t) => t.uri.equals(uri)))
            .getSingleOrNull();
    if (row == null) return null;
    return Duration(milliseconds: row.positionMs);
  }

  /// Delete a row by URI (used when a stale file is detected).
  Future<int> deleteByUri(String uri) {
    return (delete(
      playbackPositions,
    )..where(($PlaybackPositionsTable t) => t.uri.equals(uri))).go();
  }
}

/// DAO for [RecentItems]. Reverse-chronological access plus a cap (50).
@DriftAccessor(tables: <Type>[RecentItems])
class RecentItemsDao extends DatabaseAccessor<AppDatabase>
    with _$RecentItemsDaoMixin {
  RecentItemsDao(super.db);

  /// Upsert a recent-open row for [uri]; afterwards prune entries beyond
  /// [kRecentItemsCap] **scoped to [kind]** so a flood of audio opens
  /// doesn't evict video entries (and vice versa). Returns the number
  /// of pruned rows.
  Future<int> recordOpen(String uri, String kind) async {
    await into(recentItems).insertOnConflictUpdate(
      RecentItemsCompanion.insert(
        uri: uri,
        kind: kind,
        openedAt: DateTime.now().toUtc(),
      ),
    );
    return pruneOlderThan(kind, kRecentItemsCap);
  }

  /// List the most recent [limit] items (default = cap), newest first.
  /// Includes every kind (callers filter client-side when they want
  /// only one). Prefer [fetchByKind] when the caller is kind-specific.
  Future<List<RecentItemRow>> list({int limit = kRecentItemsCap}) {
    return (select(recentItems)
          ..orderBy(<OrderClauseGenerator<$RecentItemsTable>>[
            ($RecentItemsTable t) =>
                OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  /// Most recent [limit] items whose `kind` matches, newest first.
  Future<List<RecentItemRow>> fetchByKind(
    String kind, {
    int limit = kRecentItemsCap,
  }) {
    return (select(recentItems)
          ..where(($RecentItemsTable t) => t.kind.equals(kind))
          ..orderBy(<OrderClauseGenerator<$RecentItemsTable>>[
            ($RecentItemsTable t) =>
                OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  /// Delete a row by URI (used when a stale file is detected on open).
  Future<int> deleteByUri(String uri) {
    return (delete(
      recentItems,
    )..where(($RecentItemsTable t) => t.uri.equals(uri))).go();
  }

  /// Keep at most [keep] most recent entries for [kind]; delete the
  /// rest. Other kinds are untouched. Returns the number of deleted
  /// rows.
  Future<int> pruneOlderThan(String kind, int keep) async {
    final int count =
        await (selectOnly(recentItems)
              ..addColumns(<Expression<Object>>[recentItems.uri.count()])
              ..where(recentItems.kind.equals(kind)))
            .map(
              (TypedResult row) => row.read<int>(recentItems.uri.count()) ?? 0,
            )
            .getSingle();
    if (count <= keep) return 0;
    final int toDelete = count - keep;
    final List<RecentItemRow> oldest =
        await (select(recentItems)
              ..where(($RecentItemsTable t) => t.kind.equals(kind))
              ..orderBy(<OrderClauseGenerator<$RecentItemsTable>>[
                ($RecentItemsTable t) => OrderingTerm(
                  expression: t.openedAt,
                  mode: OrderingMode.asc,
                ),
              ])
              ..limit(toDelete))
            .get();
    int removed = 0;
    for (final RecentItemRow row in oldest) {
      removed += await (delete(
        recentItems,
      )..where(($RecentItemsTable t) => t.uri.equals(row.uri))).go();
    }
    return removed;
  }

  /// Backwards-compatible global cap (prunes oldest across all kinds).
  /// Retained for callers that don't care about kind isolation.
  Future<int> pruneToCap() async {
    final int count =
        await (selectOnly(recentItems)
              ..addColumns(<Expression<Object>>[recentItems.uri.count()]))
            .map(
              (TypedResult row) => row.read<int>(recentItems.uri.count()) ?? 0,
            )
            .getSingle();
    if (count <= kRecentItemsCap) return 0;
    final int toDelete = count - kRecentItemsCap;
    final List<RecentItemRow> oldest =
        await (select(recentItems)
              ..orderBy(<OrderClauseGenerator<$RecentItemsTable>>[
                ($RecentItemsTable t) => OrderingTerm(
                  expression: t.openedAt,
                  mode: OrderingMode.asc,
                ),
              ])
              ..limit(toDelete))
            .get();
    int removed = 0;
    for (final RecentItemRow row in oldest) {
      removed += await (delete(
        recentItems,
      )..where(($RecentItemsTable t) => t.uri.equals(row.uri))).go();
    }
    return removed;
  }
}

/// DAO for [NovelWorks]. Idempotent upsert + lookup + cascade-delete.
///
/// Cascade is implemented manually (drift's table-level FK declarations
/// are not used here because `NovelEpisodes` / `NovelBookmarks` are
/// keyed by `(site, externalId, ...)` not by an FK column reference).
/// [deleteWork] wraps its episodes/bookmark deletes inside a single
/// transaction.
@DriftAccessor(tables: <Type>[NovelWorks, NovelEpisodes, NovelBookmarks])
class NovelWorksDao extends DatabaseAccessor<AppDatabase>
    with _$NovelWorksDaoMixin {
  NovelWorksDao(super.db);

  Future<void> upsertWork({
    required String site,
    required String externalId,
    required String title,
    required String author,
    String? synopsis,
    required int episodeCount,
    required DateTime addedAt,
    DateTime? lastSyncedAt,
  }) {
    return into(novelWorks).insertOnConflictUpdate(
      NovelWorksCompanion.insert(
        site: site,
        externalId: externalId,
        title: title,
        author: author,
        synopsis: Value<String?>(synopsis),
        episodeCount: episodeCount,
        addedAt: addedAt,
        lastSyncedAt: Value<DateTime?>(lastSyncedAt),
      ),
    );
  }

  Future<NovelWorkRow?> getWork(String site, String externalId) {
    return (select(novelWorks)..where(
          ($NovelWorksTable t) =>
              t.site.equals(site) & t.externalId.equals(externalId),
        ))
        .getSingleOrNull();
  }

  Future<List<NovelWorkRow>> listAll() {
    return (select(novelWorks)
          ..orderBy(<OrderClauseGenerator<$NovelWorksTable>>[
            ($NovelWorksTable t) =>
                OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<NovelWorkRow>> listBySite(String site) {
    return (select(novelWorks)
          ..where(($NovelWorksTable t) => t.site.equals(site))
          ..orderBy(<OrderClauseGenerator<$NovelWorksTable>>[
            ($NovelWorksTable t) =>
                OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Cascade-delete a Work plus its episodes and bookmark inside a
  /// single transaction. Returns the number of `novel_works` rows
  /// removed (0 or 1).
  Future<int> deleteWork(String site, String externalId) async {
    return db.transaction<int>(() async {
      await (delete(novelEpisodes)..where(
            ($NovelEpisodesTable t) =>
                t.site.equals(site) & t.externalId.equals(externalId),
          ))
          .go();
      await (delete(novelBookmarks)..where(
            ($NovelBookmarksTable t) =>
                t.site.equals(site) & t.externalId.equals(externalId),
          ))
          .go();
      return (delete(novelWorks)..where(
            ($NovelWorksTable t) =>
                t.site.equals(site) & t.externalId.equals(externalId),
          ))
          .go();
    });
  }
}

/// DAO for [NovelEpisodes]. Bulk-aware upsert + lookup of missing
/// indices (used by `LibraryRepository.addToLibrary` to support
/// resume-from-partial-failure — design.md Q-D2).
@DriftAccessor(tables: <Type>[NovelEpisodes])
class NovelEpisodesDao extends DatabaseAccessor<AppDatabase>
    with _$NovelEpisodesDaoMixin {
  NovelEpisodesDao(super.db);

  Future<void> upsertEpisode({
    required String site,
    required String externalId,
    required int episodeIndex,
    required String title,
    required String body,
    required DateTime fetchedAt,
  }) {
    return into(novelEpisodes).insertOnConflictUpdate(
      NovelEpisodesCompanion.insert(
        site: site,
        externalId: externalId,
        episodeIndex: episodeIndex,
        title: title,
        body: body,
        fetchedAt: fetchedAt,
      ),
    );
  }

  Future<NovelEpisodeRow?> getEpisode(
    String site,
    String externalId,
    int episodeIndex,
  ) {
    return (select(novelEpisodes)..where(
          ($NovelEpisodesTable t) =>
              t.site.equals(site) &
              t.externalId.equals(externalId) &
              t.episodeIndex.equals(episodeIndex),
        ))
        .getSingleOrNull();
  }

  Future<List<NovelEpisodeRow>> listEpisodes(String site, String externalId) {
    return (select(novelEpisodes)
          ..where(
            ($NovelEpisodesTable t) =>
                t.site.equals(site) & t.externalId.equals(externalId),
          )
          ..orderBy(<OrderClauseGenerator<$NovelEpisodesTable>>[
            ($NovelEpisodesTable t) => OrderingTerm(expression: t.episodeIndex),
          ]))
        .get();
  }

  /// Return the set of `episodeIndex` values already persisted for the
  /// given Work. Used by [LibraryRepository.addToLibrary] to skip
  /// already-cached episodes when re-running after a partial failure.
  Future<Set<int>> existingIndices(String site, String externalId) async {
    final List<NovelEpisodeRow> rows = await listEpisodes(site, externalId);
    return rows.map((NovelEpisodeRow r) => r.episodeIndex).toSet();
  }
}

/// DAO for [NovelBookmarks]. One bookmark per Work (design.md D2).
@DriftAccessor(tables: <Type>[NovelBookmarks])
class NovelBookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$NovelBookmarksDaoMixin {
  NovelBookmarksDao(super.db);

  Future<void> upsertBookmark({
    required String site,
    required String externalId,
    required int episodeIndex,
    required double scrollFraction,
    required DateTime updatedAt,
  }) {
    return into(novelBookmarks).insertOnConflictUpdate(
      NovelBookmarksCompanion.insert(
        site: site,
        externalId: externalId,
        episodeIndex: episodeIndex,
        scrollFraction: scrollFraction,
        updatedAt: updatedAt,
      ),
    );
  }

  Future<NovelBookmarkRow?> getBookmark(String site, String externalId) {
    return (select(novelBookmarks)..where(
          ($NovelBookmarksTable t) =>
              t.site.equals(site) & t.externalId.equals(externalId),
        ))
        .getSingleOrNull();
  }

  Future<int> deleteBookmark(String site, String externalId) {
    return (delete(novelBookmarks)..where(
          ($NovelBookmarksTable t) =>
              t.site.equals(site) & t.externalId.equals(externalId),
        ))
        .go();
  }
}

/// DAO for [SiteConsents]. Adds [hasFreshConsent] helper that
/// compares the stored `policyVersion` against the currently shipping
/// one (`kPolicyVersion`), per design.md D7 / Q-D3.
@DriftAccessor(tables: <Type>[SiteConsents])
class SiteConsentsDao extends DatabaseAccessor<AppDatabase>
    with _$SiteConsentsDaoMixin {
  SiteConsentsDao(super.db);

  Future<void> setConsent({
    required String site,
    required bool granted,
    required String policyVersion,
    DateTime? decidedAt,
  }) {
    return into(siteConsents).insertOnConflictUpdate(
      SiteConsentsCompanion.insert(
        site: site,
        granted: granted,
        decidedAt: decidedAt ?? DateTime.now().toUtc(),
        policyVersion: policyVersion,
      ),
    );
  }

  Future<SiteConsentRow?> getConsent(String site) {
    return (select(
      siteConsents,
    )..where(($SiteConsentsTable t) => t.site.equals(site))).getSingleOrNull();
  }

  Future<List<SiteConsentRow>> getAll() {
    return select(siteConsents).get();
  }

  /// True iff there is a row for [site] with `granted = true` AND its
  /// stored `policyVersion` equals [currentVersion]. Returning `false`
  /// for "no row" / "granted = false" / "stale policy" lets the caller
  /// re-prompt with a single predicate.
  Future<bool> hasFreshConsent(String site, String currentVersion) async {
    final SiteConsentRow? row = await getConsent(site);
    if (row == null) return false;
    if (!row.granted) return false;
    return row.policyVersion == currentVersion;
  }

  Future<int> deleteConsent(String site) {
    return (delete(
      siteConsents,
    )..where(($SiteConsentsTable t) => t.site.equals(site))).go();
  }
}

/// DAO for [BookMetadata]. Upsert, lookup, recency ordering, and deletion
/// (with cascade to [BookBookmarks] via [BookBookmarksDao] inside a tx).
///
/// `kind = 'book'` is used in [RecentItems] to track recently opened books;
/// [recordOpen] delegates to [RecentItemsDao.recordOpen].
@DriftAccessor(tables: <Type>[BookMetadata, BookBookmarks])
class BookMetadataDao extends DatabaseAccessor<AppDatabase>
    with _$BookMetadataDaoMixin {
  BookMetadataDao(super.db);

  /// Insert or replace a book-metadata row.
  Future<void> upsert({
    required String uri,
    required String path,
    required String format,
    required String title,
    required String author,
    required int fileSizeBytes,
    required DateTime fileLastModified,
    DateTime? lastOpenedAt,
    required DateTime importedAt,
  }) {
    return into(bookMetadata).insertOnConflictUpdate(
      BookMetadataCompanion.insert(
        uri: uri,
        path: path,
        format: format,
        title: title,
        author: author,
        fileSizeBytes: fileSizeBytes,
        fileLastModified: fileLastModified,
        lastOpenedAt: Value<DateTime?>(lastOpenedAt),
        importedAt: importedAt,
      ),
    );
  }

  /// Stamp [lastOpenedAt] on the row identified by [uri].
  Future<void> touchLastOpened(String uri, DateTime openedAt) async {
    await (update(bookMetadata)
          ..where(($BookMetadataTable t) => t.uri.equals(uri)))
        .write(BookMetadataCompanion(lastOpenedAt: Value<DateTime?>(openedAt)));
  }

  /// Return the row for [uri], or `null` if absent.
  Future<BookMetadataRow?> getByUri(String uri) {
    return (select(
      bookMetadata,
    )..where(($BookMetadataTable t) => t.uri.equals(uri))).getSingleOrNull();
  }

  /// All books, newest-opened first (null last-opened sorted last).
  Future<List<BookMetadataRow>> listAll() {
    return (select(
          bookMetadata,
        )..orderBy(<OrderClauseGenerator<$BookMetadataTable>>[
          ($BookMetadataTable t) =>
              OrderingTerm(expression: t.lastOpenedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Delete a book and its bookmarks inside a single transaction.
  Future<void> deleteBook(String uri) {
    return db.transaction<void>(() async {
      await (delete(
        bookBookmarks,
      )..where(($BookBookmarksTable t) => t.bookUri.equals(uri))).go();
      await (delete(
        bookMetadata,
      )..where(($BookMetadataTable t) => t.uri.equals(uri))).go();
    });
  }
}

/// DAO for [BookBookmarks]. CRUD by book URI, ordered by creation time.
@DriftAccessor(tables: <Type>[BookBookmarks])
class BookBookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$BookBookmarksDaoMixin {
  BookBookmarksDao(super.db);

  /// Insert a new bookmark. Returns the generated [BookBookmarkRow.id].
  Future<int> addBookmark({
    required String bookUri,
    required String label,
    required int pageIndex,
    required double scrollFraction,
    required DateTime createdAt,
  }) {
    return into(bookBookmarks).insert(
      BookBookmarksCompanion.insert(
        bookUri: bookUri,
        label: label,
        pageIndex: pageIndex,
        scrollFraction: Value<double>(scrollFraction),
        createdAt: createdAt,
      ),
    );
  }

  /// All bookmarks for [bookUri], oldest-first.
  Future<List<BookBookmarkRow>> listByBook(String bookUri) {
    return (select(bookBookmarks)
          ..where(($BookBookmarksTable t) => t.bookUri.equals(bookUri))
          ..orderBy(<OrderClauseGenerator<$BookBookmarksTable>>[
            ($BookBookmarksTable t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Delete a single bookmark by [id]. Returns rows removed (0 or 1).
  Future<int> deleteById(int id) {
    return (delete(
      bookBookmarks,
    )..where(($BookBookmarksTable t) => t.id.equals(id))).go();
  }
}

/// DAO for [AppSettings]. Thin CRUD wrapper used by
/// `AppSettingsRepository` (the only intended caller per spec
/// `settings-persistence` Requirement "`app_settings` drift table").
@DriftAccessor(tables: <Type>[AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  /// Returns every persisted `(key, value)` row.
  Future<List<AppSettingRow>> getAll() {
    return select(appSettings).get();
  }

  /// Idempotent upsert. Used by `writeDiff` inside a transaction.
  Future<void> upsert(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  /// Apply a map of `(key -> value)` upserts inside a single drift
  /// transaction so `writeDiff` is all-or-nothing
  /// (`settings-persistence` Requirement "Write path is transactional").
  Future<void> upsertAll(Map<String, String> rows) {
    return db.transaction<void>(() async {
      for (final MapEntry<String, String> e in rows.entries) {
        await upsert(e.key, e.value);
      }
    });
  }

  /// Read a single value by [key]; returns `null` when absent.
  Future<String?> get(String key) async {
    final AppSettingRow? row = await (select(
      appSettings,
    )..where(($AppSettingsTable t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}

/// DAO for [MangaMetadata]. Upsert, lookup, recency ordering, and deletion
/// (with cascade to [MangaBookmarks] via transaction).
///
/// `kind = 'manga'` is used in [RecentItems] to track recently opened archives.
@DriftAccessor(tables: <Type>[MangaMetadata, MangaBookmarks])
class MangaMetadataDao extends DatabaseAccessor<AppDatabase>
    with _$MangaMetadataDaoMixin {
  MangaMetadataDao(super.db);

  /// Insert or replace a manga-metadata row.
  Future<void> upsert({
    required String uri,
    required String path,
    required String format,
    required String title,
    required int fileSizeBytes,
    required DateTime fileLastModified,
    required int pageCount,
    int? coverPageIndex,
    DateTime? lastOpenedAt,
    required DateTime importedAt,
  }) {
    return into(mangaMetadata).insertOnConflictUpdate(
      MangaMetadataCompanion.insert(
        uri: uri,
        path: path,
        format: format,
        title: title,
        fileSizeBytes: fileSizeBytes,
        fileLastModified: fileLastModified,
        pageCount: pageCount,
        coverPageIndex: Value<int?>(coverPageIndex),
        lastOpenedAt: Value<DateTime?>(lastOpenedAt),
        importedAt: importedAt,
      ),
    );
  }

  /// Stamp [lastOpenedAt] on the row identified by [uri].
  Future<void> touchLastOpened(String uri, DateTime openedAt) async {
    await (update(
      mangaMetadata,
    )..where(($MangaMetadataTable t) => t.uri.equals(uri))).write(
      MangaMetadataCompanion(lastOpenedAt: Value<DateTime?>(openedAt)),
    );
  }

  /// Return the row for [uri], or `null` if absent.
  Future<MangaMetadataRow?> getByUri(String uri) {
    return (select(
      mangaMetadata,
    )..where(($MangaMetadataTable t) => t.uri.equals(uri))).getSingleOrNull();
  }

  /// All manga archives, newest-opened first (null last-opened sorted last).
  Future<List<MangaMetadataRow>> listAll() {
    return (select(
          mangaMetadata,
        )..orderBy(<OrderClauseGenerator<$MangaMetadataTable>>[
          ($MangaMetadataTable t) =>
              OrderingTerm(expression: t.lastOpenedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Delete a manga archive and its bookmarks inside a single transaction.
  Future<void> deleteManga(String uri) {
    return db.transaction<void>(() async {
      await (delete(
        mangaBookmarks,
      )..where(($MangaBookmarksTable t) => t.mangaUri.equals(uri))).go();
      await (delete(
        mangaMetadata,
      )..where(($MangaMetadataTable t) => t.uri.equals(uri))).go();
    });
  }
}

/// DAO for [MangaBookmarks]. CRUD by manga URI, ordered by creation time.
@DriftAccessor(tables: <Type>[MangaBookmarks])
class MangaBookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$MangaBookmarksDaoMixin {
  MangaBookmarksDao(super.db);

  /// Insert a new bookmark. Returns the generated [MangaBookmarkRow.id].
  Future<int> addBookmark({
    required String mangaUri,
    required String label,
    required int pageIndex,
    required DateTime createdAt,
  }) {
    return into(mangaBookmarks).insert(
      MangaBookmarksCompanion.insert(
        mangaUri: mangaUri,
        label: label,
        pageIndex: pageIndex,
        createdAt: createdAt,
      ),
    );
  }

  /// All bookmarks for [mangaUri], oldest-first.
  Future<List<MangaBookmarkRow>> listByManga(String mangaUri) {
    return (select(mangaBookmarks)
          ..where(($MangaBookmarksTable t) => t.mangaUri.equals(mangaUri))
          ..orderBy(<OrderClauseGenerator<$MangaBookmarksTable>>[
            ($MangaBookmarksTable t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Delete a single bookmark by [id]. Returns rows removed (0 or 1).
  Future<int> deleteById(int id) {
    return (delete(
      mangaBookmarks,
    )..where(($MangaBookmarksTable t) => t.id.equals(id))).go();
  }
}

/// DAO for [MediaIndex]. Upsert, lookup, kind-filtered listing, and deletion.
@DriftAccessor(tables: <Type>[MediaIndex])
class MediaIndexDao extends DatabaseAccessor<AppDatabase>
    with _$MediaIndexDaoMixin {
  MediaIndexDao(super.db);

  /// Insert or replace a media-index row.
  Future<void> upsert({
    required String uri,
    required String path,
    required String kind,
    required String title,
    required String extension,
    required int fileSizeBytes,
    required DateTime fileLastModified,
    required DateTime scannedAt,
  }) {
    return into(mediaIndex).insertOnConflictUpdate(
      MediaIndexCompanion.insert(
        uri: uri,
        path: path,
        kind: kind,
        title: title,
        extension: extension,
        fileSizeBytes: fileSizeBytes,
        fileLastModified: fileLastModified,
        scannedAt: scannedAt,
      ),
    );
  }

  /// Return the row for [uri], or `null` if absent.
  Future<MediaIndexRow?> getByUri(String uri) {
    return (select(
      mediaIndex,
    )..where(($MediaIndexTable t) => t.uri.equals(uri))).getSingleOrNull();
  }

  /// All indexed items, newest-scanned first.
  Future<List<MediaIndexRow>> listAll() {
    return (select(mediaIndex)
          ..orderBy(<OrderClauseGenerator<$MediaIndexTable>>[
            ($MediaIndexTable t) =>
                OrderingTerm(expression: t.scannedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// All items with [kind] (`'video'` or `'audio'`), newest-scanned first.
  Future<List<MediaIndexRow>> listByKind(String kind) {
    return (select(mediaIndex)
          ..where(($MediaIndexTable t) => t.kind.equals(kind))
          ..orderBy(<OrderClauseGenerator<$MediaIndexTable>>[
            ($MediaIndexTable t) =>
                OrderingTerm(expression: t.scannedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Delete a single row by URI. Returns rows removed (0 or 1).
  Future<int> deleteByUri(String uri) {
    return (delete(
      mediaIndex,
    )..where(($MediaIndexTable t) => t.uri.equals(uri))).go();
  }
}

/// DAO for [WatchHistory]. Upsert by URI; recent-first listing.
@DriftAccessor(tables: <Type>[WatchHistory])
class WatchHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$WatchHistoryDaoMixin {
  WatchHistoryDao(super.db);

  /// Insert or update watch history for [uri].
  Future<void> upsert({
    required String uri,
    required DateTime lastPlayedAt,
    required int positionMs,
    required int durationMs,
    required bool completed,
  }) {
    return into(watchHistory).insertOnConflictUpdate(
      WatchHistoryCompanion.insert(
        uri: uri,
        lastPlayedAt: lastPlayedAt,
        positionMs: positionMs,
        durationMs: durationMs,
        completed: Value<bool>(completed),
      ),
    );
  }

  /// Return the watch history row for [uri], or `null` if absent.
  Future<WatchHistoryRow?> getByUri(String uri) {
    return (select(
      watchHistory,
    )..where(($WatchHistoryTable t) => t.uri.equals(uri))).getSingleOrNull();
  }

  /// All history rows, most-recently-played first.
  Future<List<WatchHistoryRow>> listRecent({int limit = 50}) {
    return (select(watchHistory)
          ..orderBy(<OrderClauseGenerator<$WatchHistoryTable>>[
            ($WatchHistoryTable t) => OrderingTerm(
              expression: t.lastPlayedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .get();
  }

  /// Delete a single history row by URI. Returns rows removed (0 or 1).
  Future<int> deleteByUri(String uri) {
    return (delete(
      watchHistory,
    )..where(($WatchHistoryTable t) => t.uri.equals(uri))).go();
  }
}

/// DAO for [Favorites]. Presence = favorited; absence = not favorited.
@DriftAccessor(tables: <Type>[Favorites])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  /// Mark [uri] as favorited. Idempotent.
  Future<void> add(String uri, DateTime favoritedAt) {
    return into(favorites).insertOnConflictUpdate(
      FavoritesCompanion.insert(uri: uri, favoritedAt: favoritedAt),
    );
  }

  /// Remove [uri] from favorites. Returns rows removed (0 or 1).
  Future<int> remove(String uri) {
    return (delete(
      favorites,
    )..where(($FavoritesTable t) => t.uri.equals(uri))).go();
  }

  /// `true` iff [uri] is currently favorited.
  Future<bool> isFavorite(String uri) async {
    final FavoriteRow? row = await (select(
      favorites,
    )..where(($FavoritesTable t) => t.uri.equals(uri))).getSingleOrNull();
    return row != null;
  }

  /// All favorite rows, most-recently-favorited first.
  Future<List<FavoriteRow>> listAll() {
    return (select(favorites)..orderBy(<OrderClauseGenerator<$FavoritesTable>>[
          ($FavoritesTable t) =>
              OrderingTerm(expression: t.favoritedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }
}

/// DAO for [Playlists]. CRUD plus cascade-delete of [PlaylistItems].
@DriftAccessor(tables: <Type>[Playlists, PlaylistItems])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  /// Insert a new playlist. Returns the generated id.
  Future<int> create(String name, DateTime now) {
    return into(playlists).insert(
      PlaylistsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
  }

  /// Rename a playlist and update [updatedAt].
  Future<void> rename(int id, String newName, DateTime now) async {
    await (update(
      playlists,
    )..where(($PlaylistsTable t) => t.id.equals(id))).write(
      PlaylistsCompanion(
        name: Value<String>(newName),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Return all playlists, newest-created first.
  Future<List<PlaylistRow>> listAll() {
    return (select(playlists)..orderBy(<OrderClauseGenerator<$PlaylistsTable>>[
          ($PlaylistsTable t) =>
              OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Return a single playlist by [id], or `null` if absent.
  Future<PlaylistRow?> getById(int id) {
    return (select(
      playlists,
    )..where(($PlaylistsTable t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Delete a playlist and all its items inside a single transaction.
  Future<void> deleteById(int id) {
    return db.transaction<void>(() async {
      await (delete(
        playlistItems,
      )..where(($PlaylistItemsTable t) => t.playlistId.equals(id))).go();
      await (delete(
        playlists,
      )..where(($PlaylistsTable t) => t.id.equals(id))).go();
    });
  }
}

/// DAO for [PlaylistItems]. Add, remove, reorder, and list items.
@DriftAccessor(tables: <Type>[PlaylistItems])
class PlaylistItemsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistItemsDaoMixin {
  PlaylistItemsDao(super.db);

  /// Add [mediaUri] to [playlistId] at [position].
  Future<void> add({
    required int playlistId,
    required String mediaUri,
    required int position,
  }) {
    return into(playlistItems).insertOnConflictUpdate(
      PlaylistItemsCompanion.insert(
        playlistId: playlistId,
        mediaUri: mediaUri,
        position: position,
      ),
    );
  }

  /// Remove [mediaUri] from [playlistId].
  Future<int> remove(int playlistId, String mediaUri) {
    return (delete(playlistItems)..where(
          ($PlaylistItemsTable t) =>
              t.playlistId.equals(playlistId) & t.mediaUri.equals(mediaUri),
        ))
        .go();
  }

  /// All items in [playlistId], sorted by [position] ascending.
  Future<List<PlaylistItemRow>> listByPlaylist(int playlistId) {
    return (select(playlistItems)
          ..where(($PlaylistItemsTable t) => t.playlistId.equals(playlistId))
          ..orderBy(<OrderClauseGenerator<$PlaylistItemsTable>>[
            ($PlaylistItemsTable t) =>
                OrderingTerm(expression: t.position, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Replace all items of [playlistId] with [orderedUris] (positions 0..n-1).
  Future<void> replaceAll(int playlistId, List<String> orderedUris) {
    return db.transaction<void>(() async {
      await (delete(playlistItems)
            ..where(($PlaylistItemsTable t) => t.playlistId.equals(playlistId)))
          .go();
      for (int i = 0; i < orderedUris.length; i++) {
        await into(playlistItems).insert(
          PlaylistItemsCompanion.insert(
            playlistId: playlistId,
            mediaUri: orderedUris[i],
            position: i,
          ),
        );
      }
    });
  }
}
