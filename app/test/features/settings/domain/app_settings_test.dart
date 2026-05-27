import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/settings/domain/app_settings.dart';
import 'package:geekplayer/features/settings/domain/novel_writing_mode.dart';

void main() {
  group('AppSettings.defaults()', () {
    test('matches the spec-documented default values', () {
      final AppSettings d = AppSettings.defaults();
      expect(d.themeMode, ThemeMode.system);
      expect(d.defaultPlaybackSpeed, 1.0);
      expect(d.subtitlesByDefault, false);
      expect(d.audioBackgroundPlayback, true);
      expect(d.audioNotificationPersistent, true);
      expect(d.novelWritingMode, NovelWritingMode.vertical);
      expect(d.novelFontSizeSp, 16.0);
      expect(d.novelLineHeight, 1.7);
      expect(d.novelFontFamily, 'noto-serif-jp');
      expect(d.novelBackgroundLight, 0xFFFAF7EE);
      expect(d.novelBackgroundDark, 0xFF1C1B1F);
      expect(d.recentItemsCap, 50);
      expect(d.novelCacheCapMb, isNull);
    });
  });

  group('copyWith', () {
    test('returns a new instance with the override applied', () {
      final AppSettings a = AppSettings.defaults();
      final AppSettings b = a.copyWith(novelFontSizeSp: 22.0);
      expect(identical(a, b), isFalse);
      expect(b.novelFontSizeSp, 22.0);
      // Every other field equals a's value.
      expect(b.copyWith(novelFontSizeSp: a.novelFontSizeSp), a);
    });

    test('can set novelCacheCapMb to null explicitly', () {
      final AppSettings a = AppSettings.defaults().copyWith(
        novelCacheCapMb: 500,
      );
      expect(a.novelCacheCapMb, 500);
      final AppSettings b = a.copyWith(novelCacheCapMb: null);
      expect(b.novelCacheCapMb, isNull);
    });

    test('omitting novelCacheCapMb preserves the existing value', () {
      final AppSettings a = AppSettings.defaults().copyWith(
        novelCacheCapMb: 200,
      );
      final AppSettings b = a.copyWith(novelFontSizeSp: 18.0);
      expect(b.novelCacheCapMb, 200);
    });
  });

  group('equality', () {
    test('two defaults() are ==', () {
      expect(AppSettings.defaults(), AppSettings.defaults());
      expect(AppSettings.defaults().hashCode, AppSettings.defaults().hashCode);
    });

    test('differing field breaks equality', () {
      final AppSettings a = AppSettings.defaults();
      final AppSettings b = a.copyWith(themeMode: ThemeMode.dark);
      expect(a == b, isFalse);
    });
  });
}
