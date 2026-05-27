import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/novel_bookmarks.dart';
import 'tables/novel_episodes.dart';
import 'tables/novel_works.dart';
import 'tables/playback_positions.dart';
import 'tables/recent_items.dart';
import 'tables/site_consents.dart';

part 'database.g.dart';

/// Recent-items list cap from spec L1 R4. See design.md Q-D1.
const int kRecentItemsCap = 50;

/// Single drift database for GeekPlayer.
///
/// Schema lineage (see CONVENTIONS.md §5):
///   - v1 — `add-local-video-playback`: playback_positions + recent_items
///   - v2 — `add-online-novel-library` (this change): novel_works,
///          novel_episodes, novel_bookmarks, site_consents
///   - v3 — `add-app-settings`: app_settings
@DriftDatabase(
  tables: <Type>[
    PlaybackPositions,
    RecentItems,
    NovelWorks,
    NovelEpisodes,
    NovelBookmarks,
    SiteConsents,
  ],
  daos: <Type>[
    PlaybackPositionsDao,
    RecentItemsDao,
    NovelWorksDao,
    NovelEpisodesDao,
    NovelBookmarksDao,
    SiteConsentsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for tests: pass an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 2;

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
