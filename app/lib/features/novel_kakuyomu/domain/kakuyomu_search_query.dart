import 'package:flutter/foundation.dart';

/// Sort order for Kakuyomu search results. The keys map directly to
/// the `order` query parameter on `https://kakuyomu.jp/search`.
enum KakuyomuSearchSort {
  /// 新着順 (default)
  newest,

  /// 人気順
  popular,

  /// レビュー順
  reviewed,
}

/// Input to `KakuyomuRssSource.search` / `KakuyomuNovelRepository.search`.
@immutable
class KakuyomuSearchQuery {
  const KakuyomuSearchQuery({
    required this.keyword,
    this.genre,
    this.sort = KakuyomuSearchSort.newest,
  });

  final String keyword;
  final String? genre;
  final KakuyomuSearchSort sort;

  /// Build the matching `?q=...&genre=...&order=...` query string.
  Map<String, String> toQueryParameters() {
    final Map<String, String> q = <String, String>{'q': keyword};
    if (genre != null && genre!.isNotEmpty) q['genre'] = genre!;
    q['order'] = switch (sort) {
      KakuyomuSearchSort.newest => 'published_at',
      KakuyomuSearchSort.popular => 'popular',
      KakuyomuSearchSort.reviewed => 'review_count',
    };
    return q;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KakuyomuSearchQuery &&
        other.keyword == keyword &&
        other.genre == genre &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(keyword, genre, sort);

  @override
  String toString() =>
      'KakuyomuSearchQuery("$keyword", genre=$genre, sort=$sort)';
}
