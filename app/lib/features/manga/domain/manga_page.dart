import 'package:flutter/foundation.dart';

/// Descriptor for a single image page inside a manga archive.
@immutable
class MangaPage {
  const MangaPage({required this.index, required this.entryName});

  /// 0-based index in the ordered page list.
  final int index;

  /// Entry name inside the archive (safe, no traversal components).
  final String entryName;
}
