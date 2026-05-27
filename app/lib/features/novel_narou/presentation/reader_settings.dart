import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_settings.g.dart';

/// リーダーの色テーマ。
enum ReaderColorScheme {
  light('ライト'),
  sepia('セピア'),
  dark('ダーク');

  const ReaderColorScheme(this.label);
  final String label;
}

/// リーダーで適用する文字サイズ / 行間 / 色テーマの値オブジェクト。
///
/// 仕様 `narou-novel-reader-ui` "Reader screen with vertical scroll":
///   - フォントサイズ 12〜32 pt (2 pt 刻み)
///   - 行間 1.2〜2.4 (0.2 刻み)
///   - 色テーマ light / sepia / dark
///
/// 永続化:
/// **本 wave (Wave 3) では `add-app-settings` が並列実装中で `app_settings`
/// テーブルが未存在**のため、`ReaderTheme` は **in-memory + Riverpod state
/// (`keepAlive: true`)** だけで保持する。プロセス再起動後はデフォルト値に
/// 戻る (TODO: v0.2 で app_settings バックエンドに切り替え)。
class ReaderTheme {
  const ReaderTheme({
    this.fontSize = 16,
    this.lineHeight = 1.6,
    this.colorScheme = ReaderColorScheme.light,
  });

  final double fontSize;
  final double lineHeight;
  final ReaderColorScheme colorScheme;

  ReaderTheme copyWith({
    double? fontSize,
    double? lineHeight,
    ReaderColorScheme? colorScheme,
  }) {
    return ReaderTheme(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }

  Color get background => switch (colorScheme) {
    ReaderColorScheme.light => Colors.white,
    ReaderColorScheme.sepia => const Color(0xFFF5ECD7),
    ReaderColorScheme.dark => const Color(0xFF121212),
  };

  Color get foreground => switch (colorScheme) {
    ReaderColorScheme.light => Colors.black87,
    ReaderColorScheme.sepia => const Color(0xFF3E2E1F),
    ReaderColorScheme.dark => Colors.white.withValues(alpha: 0.88),
  };
}

/// Riverpod state for [ReaderTheme]. keepAlive で全画面再入場時に保持。
///
/// TODO(v0.2): `app_settings` テーブルが利用可能になったら
/// `novel.reader.fontSize` / `novel.reader.lineHeight` /
/// `novel.reader.colorScheme` の 3 key で永続化に切り替える。
@Riverpod(keepAlive: true)
class ReaderThemeNotifier extends _$ReaderThemeNotifier {
  @override
  ReaderTheme build() => const ReaderTheme();

  void setFontSize(double v) {
    state = state.copyWith(fontSize: v.clamp(12.0, 32.0).toDouble());
  }

  void setLineHeight(double v) {
    state = state.copyWith(lineHeight: v.clamp(1.2, 2.4).toDouble());
  }

  void setColorScheme(ReaderColorScheme c) {
    state = state.copyWith(colorScheme: c);
  }
}
