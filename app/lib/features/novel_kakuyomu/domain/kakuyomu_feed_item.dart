import 'package:flutter/foundation.dart';

/// Normalized item from a Kakuyomu RSS / Atom feed (search results,
/// latest, ranking, work-update notifications).
@immutable
class KakuyomuFeedItem {
  const KakuyomuFeedItem({
    required this.title,
    required this.workId,
    required this.url,
    this.author,
    this.publishedAt,
    this.summary,
  });

  final String title;

  /// Kakuyomu work id extracted from the item link URL. May be the
  /// empty string when the link does not point to a `/works/{id}` path
  /// (e.g. work-update feeds for a single work where the id is
  /// already known from the request URL).
  final String workId;

  final String url;
  final String? author;
  final DateTime? publishedAt;
  final String? summary;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'workId': workId,
    'url': url,
    'author': author,
    'publishedAt': publishedAt?.toIso8601String(),
    'summary': summary,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KakuyomuFeedItem &&
        other.title == title &&
        other.workId == workId &&
        other.url == url &&
        other.author == author &&
        other.publishedAt == publishedAt &&
        other.summary == summary;
  }

  @override
  int get hashCode =>
      Object.hash(title, workId, url, author, publishedAt, summary);

  @override
  String toString() => 'KakuyomuFeedItem($workId, "$title")';
}
