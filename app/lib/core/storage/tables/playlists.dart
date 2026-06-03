import 'package:drift/drift.dart';

/// drift v6 schema: user-created playlists.
///
/// Introduced by `add-media-library`. Each playlist has an auto-increment
/// integer id, a display name, and timestamps.
@DataClassName('PlaylistRow')
class Playlists extends Table {
  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// User-visible playlist name.
  TextColumn get name => text()();

  /// When the playlist was created.
  DateTimeColumn get createdAt => dateTime()();

  /// When the playlist was last modified (name changed or items reordered).
  DateTimeColumn get updatedAt => dateTime()();
}
