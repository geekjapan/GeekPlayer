import 'package:drift/drift.dart';

/// drift v2 schema: "current reading position" — one row per Work.
///
/// Primary key `{site, externalId}` (NOT including episodeIndex):
/// every `Work` has at most one bookmark, which `NovelPageSession`
/// upserts on `dispose`. `scrollFraction` is stored as a `[0.0, 1.0]`
/// REAL so font / layout changes never invalidate the saved point
/// (design.md D9).
@DataClassName('NovelBookmarkRow')
class NovelBookmarks extends Table {
  TextColumn get site => text()();
  TextColumn get externalId => text()();
  IntColumn get episodeIndex => integer()();
  RealColumn get scrollFraction => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{site, externalId};
}
