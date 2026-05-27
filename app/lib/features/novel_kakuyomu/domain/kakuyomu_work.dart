import 'package:flutter/foundation.dart';

import 'kakuyomu_episode.dart';

/// Detail of a single Kakuyomu work as extracted by
/// `KakuyomuHtmlParser.parseWorkPage`.
///
/// This is the Kakuyomu-flavoured value object — distinct from the
/// site-agnostic `core/novel/models/work.dart` `Work` (which carries
/// only the columns persisted in `novel_works`). The mapping
/// `KakuyomuWorkDetail → Work` happens inside `KakuyomuNovelRepository`.
@immutable
class KakuyomuWorkDetail {
  const KakuyomuWorkDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.synopsis,
    required this.tags,
    required this.episodes,
    required this.lastUpdatedAt,
  });

  /// Kakuyomu work id (numeric string, e.g. `1177354054881131863`).
  final String id;
  final String title;
  final String author;
  final String synopsis;
  final List<String> tags;
  final List<KakuyomuEpisodeSummary> episodes;
  final DateTime? lastUpdatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'author': author,
    'synopsis': synopsis,
    'tags': tags,
    'episodes': episodes
        .map((KakuyomuEpisodeSummary e) => e.toJson())
        .toList(growable: false),
    'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KakuyomuWorkDetail) return false;
    return other.id == id &&
        other.title == title &&
        other.author == author &&
        other.synopsis == synopsis &&
        listEquals(other.tags, tags) &&
        listEquals(other.episodes, episodes) &&
        other.lastUpdatedAt == lastUpdatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    synopsis,
    Object.hashAll(tags),
    Object.hashAll(episodes),
    lastUpdatedAt,
  );

  @override
  String toString() => 'KakuyomuWorkDetail($id, "$title", ${episodes.length} eps)';
}
