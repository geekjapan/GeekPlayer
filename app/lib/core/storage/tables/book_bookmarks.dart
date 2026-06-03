import 'package:drift/drift.dart';

/// drift v4 schema: named bookmarks within a book.
///
/// Multiple bookmarks per book are supported (unlike `novel_bookmarks` which
/// stores one resume position per work). Each bookmark stores a format-neutral
/// locator: `pageIndex` (1-based PDF page or EPUB chapter index) plus an
/// optional `scrollFraction` for sub-page/sub-chapter precision.
///
/// `bookUri` is a FK-style reference to [BookMetadata.uri] but not declared as
/// a drift FK because drift FK enforcement is off by default and the manual
/// cascade in [BookMetadataDao.deleteBook] is explicit.
@DataClassName('BookBookmarkRow')
class BookBookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK to [BookMetadata.uri].
  TextColumn get bookUri => text()();

  /// User-provided or auto-generated label (e.g. "Chapter 3 start").
  TextColumn get label => text()();

  /// 1-based page (PDF) or chapter (EPUB) index.
  IntColumn get pageIndex => integer()();

  /// `[0.0, 1.0]` scroll fraction within the page/chapter. `0.0` when
  /// pointing at the beginning of the page/chapter.
  RealColumn get scrollFraction => real().withDefault(const Constant(0.0))();

  /// When the bookmark was created.
  DateTimeColumn get createdAt => dateTime()();
}
