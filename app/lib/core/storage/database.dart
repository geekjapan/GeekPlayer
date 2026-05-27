import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/playback_positions.dart';
import 'tables/recent_items.dart';

part 'database.g.dart';

/// Recent-items list cap from spec L1 R4. See design.md Q-D1.
const int kRecentItemsCap = 50;

/// Single drift database for GeekPlayer.
///
/// Schema lineage (see CONVENTIONS.md §5):
///   - v1 — `add-local-video-playback` (this change): playback_positions
///          + recent_items
///   - v2 — `add-online-novel-library`: novel_* and site_consents
///   - v3 — `add-app-settings`: app_settings
@DriftDatabase(
  tables: <Type>[PlaybackPositions, RecentItems],
  daos: <Type>[PlaybackPositionsDao, RecentItemsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for tests: pass an in-memory `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        // No onUpgrade yet — first shipped schema. Future versions append
        // their own `if (from < N) await m.createTable(...);` branches.
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
    final PlaybackPositionRow? row = await (select(playbackPositions)
          ..where(($PlaybackPositionsTable t) => t.uri.equals(uri)))
        .getSingleOrNull();
    if (row == null) return null;
    return Duration(milliseconds: row.positionMs);
  }

  /// Delete a row by URI (used when a stale file is detected).
  Future<int> deleteByUri(String uri) {
    return (delete(playbackPositions)
          ..where(($PlaybackPositionsTable t) => t.uri.equals(uri)))
        .go();
  }
}

/// DAO for [RecentItems]. Reverse-chronological access plus a cap (50).
@DriftAccessor(tables: <Type>[RecentItems])
class RecentItemsDao extends DatabaseAccessor<AppDatabase>
    with _$RecentItemsDaoMixin {
  RecentItemsDao(super.db);

  /// Upsert a recent-open row for [uri]; afterwards prune entries beyond
  /// [kRecentItemsCap]. Returns the number of pruned rows.
  Future<int> recordOpen(String uri, String kind) async {
    await into(recentItems).insertOnConflictUpdate(
      RecentItemsCompanion.insert(
        uri: uri,
        kind: kind,
        openedAt: DateTime.now().toUtc(),
      ),
    );
    return pruneToCap();
  }

  /// List the most recent [limit] items (default = cap), newest first.
  Future<List<RecentItemRow>> list({int limit = kRecentItemsCap}) {
    return (select(recentItems)
          ..orderBy(<OrderClauseGenerator<$RecentItemsTable>>[
            ($RecentItemsTable t) =>
                OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  /// Delete a row by URI (used when a stale file is detected on open).
  Future<int> deleteByUri(String uri) {
    return (delete(recentItems)
          ..where(($RecentItemsTable t) => t.uri.equals(uri)))
        .go();
  }

  /// Keep only the [kRecentItemsCap] most recent entries; delete the
  /// rest. Returns the number of deleted rows.
  Future<int> pruneToCap() async {
    final int count = await (selectOnly(recentItems)
              ..addColumns(<Expression<Object>>[recentItems.uri.count()]))
            .map(
              (TypedResult row) =>
                  row.read<int>(recentItems.uri.count()) ?? 0,
            )
            .getSingle();
    if (count <= kRecentItemsCap) return 0;
    final int toDelete = count - kRecentItemsCap;
    // Find the URIs of the oldest entries beyond the cap.
    final List<RecentItemRow> oldest = await (select(recentItems)
          ..orderBy(<OrderClauseGenerator<$RecentItemsTable>>[
            ($RecentItemsTable t) =>
                OrderingTerm(expression: t.openedAt, mode: OrderingMode.asc),
          ])
          ..limit(toDelete))
        .get();
    int removed = 0;
    for (final RecentItemRow row in oldest) {
      removed += await (delete(recentItems)
            ..where(($RecentItemsTable t) => t.uri.equals(row.uri)))
          .go();
    }
    return removed;
  }
}
