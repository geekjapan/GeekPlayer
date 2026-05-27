import 'package:flutter/foundation.dart';

/// 1-based episode index. Acts as a thin newtype around `int` for
/// type-safety on the API surface (so `EpisodeId(3)` cannot be passed
/// where a `pageIndex` is expected, etc.).
@immutable
class EpisodeId {
  EpisodeId(this.index) {
    if (index < 1) {
      throw ArgumentError.value(index, 'index', 'episode index must be >= 1');
    }
  }

  final int index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is EpisodeId && other.index == index);

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'EpisodeId($index)';
}

/// Episode metadata (title + index). Body text is fetched separately
/// via `EpisodeBody` to keep "list episodes" cheap (no body bytes).
@immutable
class Episode {
  const Episode({required this.id, required this.title});

  final EpisodeId id;
  final String title;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Episode && other.id == id && other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'Episode($id, "$title")';
}

/// In-memory episode body returned by `NovelRepository.fetchEpisodeBody`.
///
/// The body is NOT persisted by this call (design.md D3 — active caching
/// is enforced at the `LibraryRepository.addToLibrary` boundary). The
/// `fetchedAt` timestamp lets downstream UIs show "cached N minutes ago"
/// when relevant.
@immutable
class EpisodeBody {
  const EpisodeBody({required this.body, required this.fetchedAt});

  final String body;
  final DateTime fetchedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EpisodeBody &&
        other.body == body &&
        other.fetchedAt == fetchedAt;
  }

  @override
  int get hashCode => Object.hash(body, fetchedAt);
}
