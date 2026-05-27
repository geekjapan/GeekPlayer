import 'package:drift/drift.dart';

/// drift v1 schema: per-Episode last-known playback position.
///
/// Keyed by the normalized `file://` URI (see design.md D5). One row per
/// distinct video / audio episode; updated on player-screen teardown.
@DataClassName('PlaybackPositionRow')
class PlaybackPositions extends Table {
  TextColumn get uri => text()();
  IntColumn get positionMs => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}
