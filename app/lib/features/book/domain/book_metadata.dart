import 'package:flutter/foundation.dart';

import 'book_format.dart';

/// Immutable domain model for a locally-imported book file.
///
/// Mirrors the `book_metadata` drift row but lives in the domain layer so
/// upper layers never depend on drift types.
@immutable
class BookMetadata {
  const BookMetadata({
    required this.uri,
    required this.path,
    required this.format,
    required this.title,
    required this.author,
    required this.fileSizeBytes,
    required this.fileLastModified,
    this.lastOpenedAt,
    required this.importedAt,
  });

  final String uri;
  final String path;
  final BookFormat format;
  final String title;
  final String author;
  final int fileSizeBytes;
  final DateTime fileLastModified;
  final DateTime? lastOpenedAt;
  final DateTime importedAt;

  BookMetadata copyWith({
    String? uri,
    String? path,
    BookFormat? format,
    String? title,
    String? author,
    int? fileSizeBytes,
    DateTime? fileLastModified,
    DateTime? lastOpenedAt,
    DateTime? importedAt,
  }) {
    return BookMetadata(
      uri: uri ?? this.uri,
      path: path ?? this.path,
      format: format ?? this.format,
      title: title ?? this.title,
      author: author ?? this.author,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileLastModified: fileLastModified ?? this.fileLastModified,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BookMetadata && other.uri == uri);

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'BookMetadata($format, $title, uri=$uri)';
}
