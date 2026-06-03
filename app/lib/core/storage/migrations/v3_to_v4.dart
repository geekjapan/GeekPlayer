import 'package:drift/drift.dart';

/// drift v3 -> v4 migration logic.
///
/// Adds [BookMetadata] and [BookBookmarks] tables introduced by the
/// `add-pdf-epub-reader` change. Strictly additive: no existing table is
/// altered or dropped. Pre-existing rows in `playback_positions`,
/// `recent_items`, `novel_works`, `novel_episodes`, `novel_bookmarks`,
/// `site_consents`, and `app_settings` are preserved verbatim.
///
/// Exported so the migration test in
/// `app/test/core/storage/migration_v3_to_v4_test.dart` can call it directly.
Future<void> migrateV3ToV4(
  Migrator m,
  TableInfo<Table, dynamic> bookMetadata,
  TableInfo<Table, dynamic> bookBookmarks,
) async {
  await m.createTable(bookMetadata);
  await m.createTable(bookBookmarks);
}
