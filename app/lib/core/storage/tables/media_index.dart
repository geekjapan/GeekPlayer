import 'package:drift/drift.dart';

/// drift v6 schema: metadata for a locally-indexed media file.
///
/// Introduced by `add-media-library`. Primary key is the normalized file URI.
/// Scanning the same file twice upserts rather than duplicates.
@DataClassName('MediaIndexRow')
class MediaIndex extends Table {
  /// Normalized `file://` URI — primary key.
  TextColumn get uri => text()();

  /// Resolved absolute path at scan time.
  TextColumn get path => text()();

  /// Media kind: `'video'` or `'audio'`.
  TextColumn get kind => text()();

  /// Display title (filename stem, no extension).
  TextColumn get title => text()();

  /// File extension (lower-case, without dot), e.g. `'mp4'`, `'mp3'`.
  TextColumn get extension => text()();

  /// File size in bytes at scan time (used for stale-file detection).
  IntColumn get fileSizeBytes => integer()();

  /// `lastModified` timestamp of the file at scan time.
  DateTimeColumn get fileLastModified => dateTime()();

  /// When this row was first inserted.
  DateTimeColumn get scannedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}
