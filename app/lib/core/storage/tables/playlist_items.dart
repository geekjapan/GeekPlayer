import 'package:drift/drift.dart';

/// drift v6 schema: ordered items within a playlist.
///
/// Introduced by `add-media-library`. Composite primary key
/// `(playlist_id, media_uri)` prevents the same URI appearing twice in
/// the same playlist. The `position` column (0-based) drives UI ordering.
@DataClassName('PlaylistItemRow')
class PlaylistItems extends Table {
  /// Foreign key to [Playlists.id].
  IntColumn get playlistId => integer()();

  /// Normalized `file://` URI of the media item.
  TextColumn get mediaUri => text()();

  /// 0-based sort position within the playlist.
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{playlistId, mediaUri};
}
