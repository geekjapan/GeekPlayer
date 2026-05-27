import 'package:flutter/foundation.dart';

import 'work_id.dart';

/// Immutable domain entity for an online novel "Work" (full story).
///
/// Maps 1:1 to a row in the `novel_works` drift table. Field choices
/// follow design.md D2: title / author are required strings; synopsis
/// and `lastSyncedAt` are nullable. `episodeCount` is what the site
/// reports (the actual number of cached `novel_episodes` rows may
/// trail behind during a partial Library-add).
@immutable
class Work {
  const Work({
    required this.id,
    required this.title,
    required this.author,
    required this.episodeCount,
    required this.addedAt,
    this.synopsis,
    this.lastSyncedAt,
  });

  final WorkId id;
  final String title;
  final String author;
  final String? synopsis;
  final int episodeCount;
  final DateTime addedAt;
  final DateTime? lastSyncedAt;

  Work copyWith({
    WorkId? id,
    String? title,
    String? author,
    String? synopsis,
    int? episodeCount,
    DateTime? addedAt,
    DateTime? lastSyncedAt,
  }) {
    return Work(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      synopsis: synopsis ?? this.synopsis,
      episodeCount: episodeCount ?? this.episodeCount,
      addedAt: addedAt ?? this.addedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Work &&
        other.id == id &&
        other.title == title &&
        other.author == author &&
        other.synopsis == synopsis &&
        other.episodeCount == episodeCount &&
        other.addedAt == addedAt &&
        other.lastSyncedAt == lastSyncedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    synopsis,
    episodeCount,
    addedAt,
    lastSyncedAt,
  );

  @override
  String toString() => 'Work($id, "$title", $author, $episodeCount eps)';
}
