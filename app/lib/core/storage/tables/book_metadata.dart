import 'package:drift/drift.dart';

/// drift v4 schema: metadata for a locally-imported book file.
///
/// Introduced by `add-pdf-epub-reader` (CONVENTIONS.md §5, design.md D2/D3).
/// Primary key is the normalized file URI so re-importing the same file
/// upserts rather than duplicates. File-level identity fields (size,
/// lastModified) let the app detect stale entries after the file moves.
@DataClassName('BookMetadataRow')
class BookMetadata extends Table {
  /// Normalized `file://` URI — primary key.
  TextColumn get uri => text()();

  /// Resolved absolute path at import time (display + open shortcut).
  TextColumn get path => text()();

  /// Book format discriminator: `'pdf'` or `'epub'`.
  TextColumn get format => text()();

  /// Title extracted from document metadata, or filename fallback.
  TextColumn get title => text()();

  /// Author extracted from document metadata, or empty string.
  TextColumn get author => text()();

  /// File size in bytes at import time (stale-file detection).
  IntColumn get fileSizeBytes => integer()();

  /// `lastModified` timestamp of the file at import time (stale detection).
  DateTimeColumn get fileLastModified => dateTime()();

  /// When the book was last opened. `null` means imported but never read.
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  /// When the record was first created.
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}
