import 'package:drift/drift.dart';

/// drift v4 -> v5 migration logic.
///
/// Adds [MangaMetadata] and [MangaBookmarks] tables introduced by the
/// `add-manga-zip-viewer` change. Strictly additive: no existing table is
/// altered or dropped. Pre-existing rows in `playback_positions`,
/// `recent_items`, `novel_works`, `novel_episodes`, `novel_bookmarks`,
/// `site_consents`, `app_settings`, `book_metadata`, and `book_bookmarks`
/// are preserved verbatim.
///
/// Exported so the migration test in
/// `app/test/core/storage/migration_v4_to_v5_test.dart` can call it directly.
Future<void> migrateV4ToV5(
  Migrator m,
  TableInfo<Table, dynamic> mangaMetadata,
  TableInfo<Table, dynamic> mangaBookmarks,
) async {
  await m.createTable(mangaMetadata);
  await m.createTable(mangaBookmarks);
}
