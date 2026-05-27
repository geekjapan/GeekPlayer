import 'package:drift/drift.dart';

/// drift v2 -> v3 migration logic.
///
/// Adds the EAV `app_settings(key TEXT PK, value TEXT)` table introduced
/// by the `add-app-settings` change. Strictly additive: no existing table
/// is altered or dropped. Pre-existing rows in `playback_positions`,
/// `recent_items`, `novel_works`, `novel_episodes`, `novel_bookmarks`,
/// and `site_consents` are preserved verbatim.
///
/// Exported here so the migration test in
/// `app/test/core/storage/migration_v2_to_v3_test.dart` can call it
/// directly without instantiating the full [AppDatabase] migrator.
Future<void> migrateV2ToV3(
  Migrator m,
  TableInfo<Table, dynamic> appSettings,
) async {
  await m.createTable(appSettings);
}
