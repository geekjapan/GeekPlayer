import 'package:drift/drift.dart';

/// drift v5 schema: named bookmarks within a manga archive.
///
/// Multiple bookmarks per archive are supported. Each bookmark stores a
/// 0-based `pageIndex` (spread anchor) for the page the user bookmarked.
///
/// `mangaUri` is a FK-style reference to [MangaMetadata.uri] but not declared
/// as a drift FK. Manual cascade is handled by [MangaMetadataDao.deleteManga].
@DataClassName('MangaBookmarkRow')
class MangaBookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK to [MangaMetadata.uri].
  TextColumn get mangaUri => text()();

  /// User-provided or auto-generated label.
  TextColumn get label => text()();

  /// 0-based page index (spread anchor page).
  IntColumn get pageIndex => integer()();

  /// When the bookmark was created.
  DateTimeColumn get createdAt => dateTime()();
}
