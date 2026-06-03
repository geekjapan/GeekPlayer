import 'package:flutter/foundation.dart';

import 'manga_page.dart';

/// Domain model for an opened manga archive.
@immutable
class MangaArchive {
  const MangaArchive({
    required this.uri,
    required this.path,
    required this.title,
    required this.format,
    required this.pageCount,
    required this.pages,
    this.coverPageIndex,
  });

  /// Normalized `file://` URI.
  final String uri;

  /// Absolute filesystem path.
  final String path;

  /// Display title.
  final String title;

  /// `'cbz'` or `'zip'`.
  final String format;

  /// Total number of image pages.
  final int pageCount;

  /// Ordered list of page descriptors.
  final List<MangaPage> pages;

  /// 0-based index of the cover page, if known.
  final int? coverPageIndex;
}
