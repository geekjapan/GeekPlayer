/// Design tokens — the single source of truth for spacing, radii,
/// breakpoints, and sizing used across GeekPlayer's UI.
///
/// These are plain compile-time constants (no `ThemeExtension` yet): later
/// widget work references them instead of magic numbers so the app keeps a
/// consistent rhythm. See spec `ui-design-system`.
library;

/// Spacing scale in logical pixels (4dp base).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner-radius scale in logical pixels.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  /// Pill / fully-rounded.
  static const double full = 999;
}

/// Responsive breakpoints (window width in logical pixels).
abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 1024;
}

/// Misc sizing tokens.
abstract final class AppSizes {
  /// Minimum interactive target (Material accessibility guideline).
  static const double minTouchTarget = 48;

  /// Max width for list/form content on wide windows.
  static const double maxContentWidth = 840;

  /// Max width for long-form prose (keeps lines ~45-75 chars).
  static const double maxReaderWidth = 680;
}
