import 'package:flutter/foundation.dart';

/// Position within a manga archive.
///
/// [pageIndex] is 0-based and represents the current page or spread anchor.
@immutable
class MangaLocator {
  const MangaLocator({this.pageIndex = 0});

  /// 0-based page index (spread anchor in spread mode).
  final int pageIndex;

  MangaLocator copyWith({int? pageIndex}) =>
      MangaLocator(pageIndex: pageIndex ?? this.pageIndex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaLocator && other.pageIndex == pageIndex);

  @override
  int get hashCode => pageIndex.hashCode;

  @override
  String toString() => 'MangaLocator(pageIndex: $pageIndex)';
}
