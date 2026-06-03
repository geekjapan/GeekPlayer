import 'package:flutter/foundation.dart';

import 'manga_locator.dart';

/// A user-created named bookmark within a manga archive.
@immutable
class MangaBookmark {
  const MangaBookmark({
    required this.id,
    required this.mangaUri,
    required this.label,
    required this.locator,
    required this.createdAt,
  });

  final int id;
  final String mangaUri;
  final String label;
  final MangaLocator locator;
  final DateTime createdAt;
}
