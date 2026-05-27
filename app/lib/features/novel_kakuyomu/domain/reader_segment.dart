import 'package:flutter/foundation.dart';

/// One renderable atom of an episode body, produced by
/// `KakuyomuHtmlParser`. The reader screen walks the list and emits
/// `Text.rich` spans / blank lines / ruby pairs accordingly.
@immutable
sealed class ReaderSegment {
  const ReaderSegment();

  Map<String, dynamic> toJson();
}

/// A plain paragraph of text (no inline ruby).
@immutable
final class ParagraphSegment extends ReaderSegment {
  const ParagraphSegment(this.text);

  final String text;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'paragraph',
    'text': text,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ParagraphSegment && other.text == text);

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'ParagraphSegment("$text")';
}

/// A vertical blank line (`<br>` or empty `<p>` between paragraphs).
@immutable
final class BlankLineSegment extends ReaderSegment {
  const BlankLineSegment();

  @override
  Map<String, dynamic> toJson() => const <String, dynamic>{'type': 'blank'};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BlankLineSegment;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'BlankLineSegment';
}

/// A paragraph containing one or more inline ruby spans.
///
/// `runs` alternates between plain text and ruby pairs. We don't model
/// nested formatting (bold, italics, etc.) — Kakuyomu body HTML rarely
/// uses them inside paragraph text.
@immutable
final class RubyParagraphSegment extends ReaderSegment {
  const RubyParagraphSegment(this.runs);

  final List<RubyRun> runs;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'rubyParagraph',
    'runs': runs.map((RubyRun r) => r.toJson()).toList(growable: false),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RubyParagraphSegment) return false;
    if (other.runs.length != runs.length) return false;
    for (int i = 0; i < runs.length; i++) {
      if (other.runs[i] != runs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(runs);

  @override
  String toString() => 'RubyParagraphSegment($runs)';
}

/// A single run inside a [RubyParagraphSegment].
@immutable
sealed class RubyRun {
  const RubyRun();
  Map<String, dynamic> toJson();
}

@immutable
final class TextRun extends RubyRun {
  const TextRun(this.text);
  final String text;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': 'text', 'text': text};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TextRun && other.text == text);

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextRun("$text")';
}

@immutable
final class RubyPair extends RubyRun {
  const RubyPair({required this.base, required this.reading});

  /// The base text (e.g. 「漢字」).
  final String base;

  /// The ruby reading (e.g. 「かんじ」).
  final String reading;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': 'ruby', 'base': base, 'reading': reading};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RubyPair && other.base == base && other.reading == reading;
  }

  @override
  int get hashCode => Object.hash(base, reading);

  @override
  String toString() => 'RubyPair($base / $reading)';
}
