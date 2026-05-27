import 'package:drift/drift.dart';

/// drift v3 schema: key-value app settings (EAV).
///
/// Per `add-app-settings` design D1, every user-facing setting is stored
/// as a single `(key TEXT, value TEXT)` row. Type information lives in
/// `features/settings/data/settings_codec.dart`; the DB column itself is
/// always TEXT. This keeps the schema flat as the set of settings grows.
///
/// All rows MUST be inserted, read, and updated through
/// `AppSettingsRepository`; no other class should issue raw SQL against
/// this table (spec `settings-persistence` Requirement "`app_settings`
/// drift table").
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};

  @override
  String get tableName => 'app_settings';
}
