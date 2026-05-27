import 'package:flutter/material.dart';

/// なろう / R18 系統の独自ルビ記法を `InlineSpan` 列に展開する。
///
/// 対応する記法（design.md D9 / 仕様 `narou-novel-reader-ui` "Ruby
/// markup is rendered as ruby annotations"）:
///
///   - `|漢字《かんじ》` — `|` で開始、`《...》` がルビ文字列。
///   - `《単語》` 直前 1 文字 — 漢字 1 文字 + `《》` パターン（簡易検出）。
///   - `<i...>` — 挿絵タグ。**v0.1 では `[挿絵]` プレースホルダ**として描画。
///
/// レンダリング:
///   - 通常テキストは `TextSpan(text:..., style: base)`
///   - ルビ付きは `WidgetSpan(child: _Ruby(...))` で漢字の上に小さな
///     ルビをラスタライズする。
class NarouRubyParser {
  const NarouRubyParser();

  /// [text] を解析し、`SelectableText.rich` / `RichText` に渡せる
  /// `InlineSpan` の列を返す。`baseStyle` は本文の `TextStyle`。
  List<InlineSpan> parse(String text, {TextStyle? baseStyle}) {
    final List<InlineSpan> out = <InlineSpan>[];
    int i = 0;
    while (i < text.length) {
      final int barIndex = text.indexOf('|', i);
      final int openIndex = text.indexOf('《', i);
      final int illustIndex = text.indexOf('<i', i);

      // 一番手前にあるトークン (見つからなければ -1) を選ぶ。
      int next = -1;
      String token = '';
      void consider(int idx, String t) {
        if (idx < 0) return;
        if (next < 0 || idx < next) {
          next = idx;
          token = t;
        }
      }

      consider(barIndex, 'bar');
      consider(openIndex, 'open');
      consider(illustIndex, 'illust');

      if (next < 0) {
        // 残り全部をプレーンとして詰める。
        out.add(TextSpan(text: text.substring(i), style: baseStyle));
        break;
      }
      if (next > i) {
        out.add(TextSpan(text: text.substring(i, next), style: baseStyle));
      }
      if (token == 'bar') {
        // `|本文《ルビ》` — `|` の直後から `《` までが base、`《》` がルビ
        final int kOpen = text.indexOf('《', next + 1);
        final int kClose = kOpen < 0 ? -1 : text.indexOf('》', kOpen + 1);
        if (kOpen < 0 || kClose < 0) {
          // 不完全 — `|` を 1 文字として通す。
          out.add(TextSpan(text: '|', style: baseStyle));
          i = next + 1;
          continue;
        }
        final String base = text.substring(next + 1, kOpen);
        final String ruby = text.substring(kOpen + 1, kClose);
        out.add(
          WidgetSpan(
            child: _Ruby(base: base, ruby: ruby, style: baseStyle),
          ),
        );
        i = kClose + 1;
        continue;
      }
      if (token == 'open') {
        // `X《ルビ》` — 直前 1 文字が base
        if (next == i) {
          // 直前に文字がない場合は素通し
          out.add(TextSpan(text: '《', style: baseStyle));
          i = next + 1;
          continue;
        }
        // 既に上で text[i..next] を出してしまっているので、その最後の 1 文字を
        // ルビベースに振り替える。
        final InlineSpan lastSpan = out.removeLast();
        if (lastSpan is TextSpan && (lastSpan.text ?? '').isNotEmpty) {
          final String prefix = lastSpan.text!;
          final String base = prefix.substring(prefix.length - 1);
          final String head = prefix.substring(0, prefix.length - 1);
          if (head.isNotEmpty) {
            out.add(TextSpan(text: head, style: baseStyle));
          }
          final int kClose = text.indexOf('》', next + 1);
          if (kClose < 0) {
            out.add(TextSpan(text: '$base《', style: baseStyle));
            i = next + 1;
            continue;
          }
          final String ruby = text.substring(next + 1, kClose);
          out.add(
            WidgetSpan(
              child: _Ruby(base: base, ruby: ruby, style: baseStyle),
            ),
          );
          i = kClose + 1;
          continue;
        }
        // フォールバック
        out.add(TextSpan(text: '《', style: baseStyle));
        i = next + 1;
        continue;
      }
      if (token == 'illust') {
        // `<i123|456|789>` を `[挿絵]` に置換。`>` までを 1 単位として消費。
        final int close = text.indexOf('>', next + 1);
        if (close < 0) {
          out.add(TextSpan(text: '<i', style: baseStyle));
          i = next + 2;
          continue;
        }
        out.add(TextSpan(text: '[挿絵]', style: baseStyle));
        i = close + 1;
        continue;
      }
    }
    return out;
  }

  /// ルビ記法を完全に剥がしたプレーン文字列を返す。
  /// `SelectableText` のコピー結果（仕様 "Selectable text supports copy"）
  /// は `WidgetSpan` 由来のため、明示的にプレーン化したい場合に使う。
  String stripMarkup(String text) {
    String s = text;
    // `|漢字《かんじ》` → `漢字`
    s = s.replaceAllMapped(
      RegExp(r'\|([^《|]+)《[^》]+》'),
      (Match m) => m.group(1) ?? '',
    );
    // `X《ルビ》` → `X`
    s = s.replaceAllMapped(
      RegExp(r'([぀-ゟ゠-ヿ一-鿿])《[^》]+》'),
      (Match m) => m.group(1) ?? '',
    );
    // 挿絵タグ
    s = s.replaceAll(RegExp(r'<i[^>]*>'), '[挿絵]');
    return s;
  }
}

class _Ruby extends StatelessWidget {
  const _Ruby({required this.base, required this.ruby, this.style});

  final String base;
  final String ruby;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final TextStyle effective = style ?? DefaultTextStyle.of(context).style;
    final double rubySize = (effective.fontSize ?? 14) * 0.55;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(ruby, style: effective.copyWith(fontSize: rubySize, height: 1.0)),
        Text(base, style: effective),
      ],
    );
  }
}
