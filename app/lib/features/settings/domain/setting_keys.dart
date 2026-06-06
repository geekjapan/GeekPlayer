/// Stable dotted-namespace keys for rows in the `app_settings` table.
///
/// Once a key ships in a release, the string SHALL NOT be renamed —
/// any rename MUST be a new key plus an `onUpgrade` migration that
/// copies the old value over (spec `settings-persistence` Requirement
/// "Setting keys are namespaced and stable").
///
/// All keys MUST match the regex `^[a-z][a-z_]*(\.[a-z][a-z_]*)+$`.
class SettingKeys {
  const SettingKeys._();

  // Display.
  static const String themeMode = 'theme.mode';

  // Playback (generic).
  static const String defaultPlaybackSpeed = 'playback.default_speed';

  // Video.
  static const String subtitlesByDefault = 'video.subtitles_default';

  // Audio.
  static const String audioBackgroundPlayback = 'audio.background_playback';
  static const String audioNotificationPersistent =
      'audio.notification_persistent';

  // Novel reader.
  static const String novelWritingMode = 'novel.writing_mode';
  static const String novelFontSizeSp = 'novel.font_size_sp';
  static const String novelLineHeight = 'novel.line_height';
  static const String novelFontFamily = 'novel.font_family';
  static const String novelBackgroundLight = 'novel.background_light';
  static const String novelBackgroundDark = 'novel.background_dark';

  // Library.
  static const String recentItemsCap = 'library.recent_cap';

  // Cache.
  static const String novelCacheCapMb = 'cache.cap_mb';

  // Experimental — AI image upscaling (ADR-0007 step 3 / step 4).
  static const String aiUpscaleEnabled = 'experimental.ai_upscale_enabled';
  static const String aiUpscaleScale = 'experimental.ai_upscale_scale';
  static const String aiUpscaleBackendOverride =
      'experimental.ai_upscale_backend_override';

  /// Every persisted setting key. Order is informational only; the
  /// repository writes only the diff between two snapshots.
  static const List<String> all = <String>[
    themeMode,
    defaultPlaybackSpeed,
    subtitlesByDefault,
    audioBackgroundPlayback,
    audioNotificationPersistent,
    novelWritingMode,
    novelFontSizeSp,
    novelLineHeight,
    novelFontFamily,
    novelBackgroundLight,
    novelBackgroundDark,
    recentItemsCap,
    novelCacheCapMb,
    aiUpscaleEnabled,
    aiUpscaleScale,
    aiUpscaleBackendOverride,
  ];
}
