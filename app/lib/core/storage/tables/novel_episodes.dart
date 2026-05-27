import 'package:drift/drift.dart';

/// drift v2 schema: cached episode bodies for online novels.
///
/// Composite primary key `{site, externalId, episodeIndex}`. `body` is
/// the plain-text (or lightweight markup) episode content. Per
/// design.md D3, rows are written ONLY by `LibraryRepository.addToLibrary`
/// — `NovelRepository.fetchEpisodeBody` itself never persists. This
/// enforces the active-caching invariant declared in ADR-0001.
@DataClassName('NovelEpisodeRow')
class NovelEpisodes extends Table {
  TextColumn get site => text()();
  TextColumn get externalId => text()();
  IntColumn get episodeIndex => integer()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
        site,
        externalId,
        episodeIndex,
      };
}
