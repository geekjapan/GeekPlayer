import 'package:flutter/foundation.dart';

/// Domain model for manga archive metadata stored in the database.
@immutable
class MangaMetadata {
  const MangaMetadata({
    required this.uri,
    required this.path,
    required this.format,
    required this.title,
    required this.fileSizeBytes,
    required this.fileLastModified,
    required this.pageCount,
    this.coverPageIndex,
    required this.importedAt,
    this.lastOpenedAt,
  });

  final String uri;
  final String path;

  /// `'cbz'` or `'zip'`.
  final String format;

  final String title;
  final int fileSizeBytes;
  final DateTime fileLastModified;
  final int pageCount;
  final int? coverPageIndex;
  final DateTime importedAt;
  final DateTime? lastOpenedAt;
}
