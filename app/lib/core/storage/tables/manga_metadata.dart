import 'package:drift/drift.dart';

/// drift v5 schema: metadata for a locally-imported manga archive.
///
/// Introduced by `add-manga-zip-viewer` (CONVENTIONS.md §5, design.md D2/D3).
/// Primary key is the normalized file URI so re-importing the same file
/// upserts rather than duplicates.
@DataClassName('MangaMetadataRow')
class MangaMetadata extends Table {
  /// Normalized `file://` URI — primary key.
  TextColumn get uri => text()();

  /// Resolved absolute path at import time.
  TextColumn get path => text()();

  /// Archive format discriminator: `'cbz'` or `'zip'`.
  TextColumn get format => text()();

  /// Display title (filename without extension by default).
  TextColumn get title => text()();

  /// File size in bytes at import time (stale-file detection).
  IntColumn get fileSizeBytes => integer()();

  /// `lastModified` timestamp of the file at import time.
  DateTimeColumn get fileLastModified => dateTime()();

  /// Total image-page count extracted from the archive.
  IntColumn get pageCount => integer()();

  /// Index (0-based) of the page used as cover art. `null` if unavailable.
  IntColumn get coverPageIndex => integer().nullable()();

  /// When the record was first created.
  DateTimeColumn get importedAt => dateTime()();

  /// When the archive was last opened. `null` means imported but never read.
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}
