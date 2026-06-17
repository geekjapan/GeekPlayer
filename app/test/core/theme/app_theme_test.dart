import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/theme/app_theme.dart';
import 'package:geekplayer/core/theme/tokens.dart';

void main() {
  group('buildAppTheme', () {
    test('is Material 3 and seeded for both brightnesses', () {
      final ThemeData light = buildAppTheme(Brightness.light);
      final ThemeData dark = buildAppTheme(Brightness.dark);

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('derives the color scheme from the brand seed', () {
      final ColorScheme expected = ColorScheme.fromSeed(
        seedColor: kSeedColor,
        brightness: Brightness.dark,
      );

      expect(
        buildAppTheme(Brightness.dark).colorScheme.primary,
        expected.primary,
      );
    });

    test('uses floating snack bars', () {
      expect(
        buildAppTheme(Brightness.dark).snackBarTheme.behavior,
        SnackBarBehavior.floating,
      );
    });
  });

  group('tokens', () {
    test('expose the documented scales', () {
      expect(AppSpacing.lg, 16);
      expect(AppRadius.md, 12);
      expect(AppSizes.minTouchTarget, 48);
      expect(AppSizes.maxReaderWidth, 680);
    });
  });
}
