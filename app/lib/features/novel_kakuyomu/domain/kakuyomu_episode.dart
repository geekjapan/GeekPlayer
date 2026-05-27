import 'package:flutter/foundation.dart';

import 'reader_segment.dart';

/// Lightweight episode descriptor returned in
/// `KakuyomuWorkDetail.episodes` (title + Kakuyomu id + published-at).
@immutable
class KakuyomuEpisodeSummary {
  const KakuyomuEpisodeSummary({
    required this.id,
    required this.title,
    required this.publishedAt,
  });

  /// Kakuyomu episode id (numeric string).
  final String id;
  final String title;
  final DateTime? publishedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'publishedAt': publishedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KakuyomuEpisodeSummary &&
        other.id == id &&
        other.title == title &&
        other.publishedAt == publishedAt;
  }

  @override
  int get hashCode => Object.hash(id, title, publishedAt);

  @override
  String toString() => 'KakuyomuEpisodeSummary($id, "$title")';
}

/// Parsed body of a single episode, as a sequence of [ReaderSegment]s.
@immutable
class KakuyomuEpisodeBody {
  const KakuyomuEpisodeBody({
    required this.id,
    required this.title,
    required this.paragraphs,
  });

  /// Kakuyomu episode id.
  final String id;
  final String title;
  final List<ReaderSegment> paragraphs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'paragraphs': paragraphs
        .map((ReaderSegment s) => s.toJson())
        .toList(growable: false),
  };

  /// Render the body as plain text (paragraphs joined by `\n\n`,
  /// blank-line segments as additional `\n`, ruby base text only).
  /// Used by `LibraryRepository` to persist a flat `body` column.
  String toPlainText() {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < paragraphs.length; i++) {
      final ReaderSegment seg = paragraphs[i];
      switch (seg) {
        case ParagraphSegment(:final String text):
          out.write(text);
        case BlankLineSegment():
          // blank line — emit nothing here; the join below produces it.
          break;
        case RubyParagraphSegment(:final List<RubyRun> runs):
          for (final RubyRun r in runs) {
            switch (r) {
              case TextRun(:final String text):
                out.write(text);
              case RubyPair(:final String base):
                out.write(base);
            }
          }
      }
      if (i + 1 < paragraphs.length) out.write('\n');
    }
    return out.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KakuyomuEpisodeBody &&
        other.id == id &&
        other.title == title &&
        listEquals(other.paragraphs, paragraphs);
  }

  @override
  int get hashCode => Object.hash(id, title, Object.hashAll(paragraphs));

  @override
  String toString() =>
      'KakuyomuEpisodeBody($id, "$title", ${paragraphs.length} segs)';
}
