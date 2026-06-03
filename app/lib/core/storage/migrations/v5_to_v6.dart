import 'package:drift/drift.dart';

/// drift v5 -> v6 migration logic.
///
/// Adds [MediaIndex], [WatchHistory], [Favorites], [Playlists], and
/// [PlaylistItems] tables introduced by the `add-media-library` change.
/// Strictly additive: no existing table is altered or dropped.
/// Pre-existing rows in `playback_positions`, `recent_items`, `novel_works`,
/// `novel_episodes`, `novel_bookmarks`, `site_consents`, `app_settings`,
/// `book_metadata`, `book_bookmarks`, `manga_metadata`, and `manga_bookmarks`
/// are preserved verbatim.
///
/// Exported so the migration test in
/// `app/test/core/storage/migration_v5_to_v6_test.dart` can call it directly.
Future<void> migrateV5ToV6(
  Migrator m,
  TableInfo<Table, dynamic> mediaIndex,
  TableInfo<Table, dynamic> watchHistory,
  TableInfo<Table, dynamic> favorites,
  TableInfo<Table, dynamic> playlists,
  TableInfo<Table, dynamic> playlistItems,
) async {
  await m.createTable(mediaIndex);
  await m.createTable(watchHistory);
  await m.createTable(favorites);
  await m.createTable(playlists);
  await m.createTable(playlistItems);
}
