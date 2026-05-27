import 'package:drift/drift.dart';

/// drift v2 schema: a `Work` saved to the user's online-novel Library.
///
/// Introduced by `add-online-novel-library` (CONVENTIONS.md §5).
/// Composite primary key `{site, externalId}` mirrors `WorkId` in the
/// domain layer (design.md D2). `site` stores the stable [Site.code]
/// string (never the enum index) so future sources can be added with
/// no DB migration.
@DataClassName('NovelWorkRow')
class NovelWorks extends Table {
  TextColumn get site => text()();
  TextColumn get externalId => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get synopsis => text().nullable()();
  IntColumn get episodeCount => integer()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{site, externalId};
}
