import 'package:drift/drift.dart';

/// drift v6 schema: per-item watch/play history.
///
/// Introduced by `add-media-library`. URI is the primary key; upsert
/// semantics mean replaying an item updates the existing row.
@DataClassName('WatchHistoryRow')
class WatchHistory extends Table {
  /// Normalized `file://` URI — primary key.
  TextColumn get uri => text()();

  /// When the item was last played.
  DateTimeColumn get lastPlayedAt => dateTime()();

  /// Last known playback position in milliseconds.
  IntColumn get positionMs => integer()();

  /// Total duration in milliseconds (`0` if unknown at record time).
  IntColumn get durationMs => integer()();

  /// Whether the item was played to completion (within the last 5 % of duration).
  BoolColumn get completed =>
      boolean().withDefault(const Constant<bool>(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}
