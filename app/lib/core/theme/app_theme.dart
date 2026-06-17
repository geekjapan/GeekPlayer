import 'package:flutter/material.dart';

import 'tokens.dart';

/// The single GeekPlayer brand seed. Both the light and dark color schemes are
/// generated from this via [ColorScheme.fromSeed], so they cannot drift.
///
/// Teal `#109A78` is a calm, content-forward chrome that lets colorful media
/// artwork be the visual hero (see spec `ui-design-system`).
const Color kSeedColor = Color(0xFF109A78);

/// Builds the app-wide [ThemeData] for [brightness].
///
/// `main.dart` calls this for `theme` (light) and `darkTheme` (dark). This is
/// the single hook every app-wide component theme and design token plugs into.
ThemeData buildAppTheme(Brightness brightness) {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(
      elevation: 1,
      margin: EdgeInsets.all(AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: AppSpacing.sm,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSizes.minTouchTarget),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSizes.minTouchTarget),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppSizes.minTouchTarget),
      ),
    ),
    sliderTheme: const SliderThemeData(trackHeight: 3),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
    ),
  );
}
