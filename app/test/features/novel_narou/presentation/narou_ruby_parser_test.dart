import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/novel_narou/presentation/narou_ruby_parser.dart';

void main() {
  const NarouRubyParser parser = NarouRubyParser();

  test('|魔王《まおう》 は WidgetSpan に展開され、stripMarkup でプレーン化', () {
    final List<InlineSpan> spans = parser.parse('|魔王《まおう》は森');
    // 0: WidgetSpan(魔王/まおう), 1: "は森"
    expect(spans.length, 2);
    expect(spans[0], isA<WidgetSpan>());
    expect((spans[1] as TextSpan).text, 'は森');
    expect(parser.stripMarkup('|魔王《まおう》は森'), '魔王は森');
  });

  test('1 文字 + 《ルビ》 パターンも展開される', () {
    // "山《やま》" → 'X《ruby》' (X = 山)
    final List<InlineSpan> spans = parser.parse('山《やま》に登る');
    // 期待: WidgetSpan(山/やま) + "に登る"
    // ただし parser のロジック上、最初の "山" は通常 TextSpan として
    // 出てから 《》 解析で WidgetSpan に振り替えられる
    expect(spans.last, isA<TextSpan>());
    expect((spans.last as TextSpan).text, 'に登る');
    expect(spans.first, isA<WidgetSpan>());
  });

  test('挿絵タグは [挿絵] にプレースホルダ', () {
    final List<InlineSpan> spans = parser.parse('前<i123|456|789>後');
    expect(spans.length, 3);
    expect((spans[0] as TextSpan).text, '前');
    expect((spans[1] as TextSpan).text, '[挿絵]');
    expect((spans[2] as TextSpan).text, '後');
  });

  test('プレーンテキストは 1 TextSpan に', () {
    final List<InlineSpan> spans = parser.parse('プレーンな本文。');
    expect(spans.length, 1);
    expect((spans.single as TextSpan).text, 'プレーンな本文。');
  });

  test('不完全な | はそのまま素通し', () {
    final List<InlineSpan> spans = parser.parse('a|b');
    // bar は見つかるが 《》 がない → '|' を 1 文字として通す
    expect(parser.stripMarkup('a|b'), 'a|b');
    expect(spans.isNotEmpty, isTrue);
  });
}
