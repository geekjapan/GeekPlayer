import 'package:flutter/material.dart' show ThemeMode;

import 'novel_writing_mode.dart';

/// Immutable snapshot of every user-tunable setting in the app.
///
/// One canonical instance lives in `AppSettingsNotifier`. Persistence
/// goes through `AppSettingsRepository`, which writes diffs to the
/// `app_settings` drift table (EAV). Feature widgets MUST consume
/// individual fields via `ref.watch(appSettingsNotifierProvider.select(...))`
/// to avoid rebuilding on unrelated changes.
///
/// Defaults are documented in spec `settings-persistence` Requirement
/// "`AppSettings` value object with typed fields and defaults".
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.defaultPlaybackSpeed,
    required this.subtitlesByDefault,
    required this.audioBackgroundPlayback,
    required this.audioNotificationPersistent,
    required this.novelWritingMode,
    required this.novelFontSizeSp,
    required this.novelLineHeight,
    required this.novelFontFamily,
    required this.novelBackgroundLight,
    required this.novelBackgroundDark,
    required this.recentItemsCap,
    required this.novelCacheCapMb,
  });

  /// Spec-mandated defaults. Keep this method in sync with the spec.
  factory AppSettings.defaults() => const AppSettings(
    themeMode: ThemeMode.system,
    defaultPlaybackSpeed: 1.0,
    subtitlesByDefault: false,
    audioBackgroundPlayback: true,
    audioNotificationPersistent: true,
    novelWritingMode: NovelWritingMode.vertical,
    novelFontSizeSp: 16.0,
    novelLineHeight: 1.7,
    novelFontFamily: 'noto-serif-jp',
    novelBackgroundLight: 0xFFFAF7EE,
    novelBackgroundDark: 0xFF1C1B1F,
    recentItemsCap: 50,
    novelCacheCapMb: null,
  );

  final ThemeMode themeMode;
  final double defaultPlaybackSpeed;
  final bool subtitlesByDefault;
  final bool audioBackgroundPlayback;
  final bool audioNotificationPersistent;
  final NovelWritingMode novelWritingMode;
  final double novelFontSizeSp;
  final double novelLineHeight;
  final String novelFontFamily;
  final int novelBackgroundLight;
  final int novelBackgroundDark;
  final int recentItemsCap;

  /// Null means "無制限" (no cap).
  final int? novelCacheCapMb;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? defaultPlaybackSpeed,
    bool? subtitlesByDefault,
    bool? audioBackgroundPlayback,
    bool? audioNotificationPersistent,
    NovelWritingMode? novelWritingMode,
    double? novelFontSizeSp,
    double? novelLineHeight,
    String? novelFontFamily,
    int? novelBackgroundLight,
    int? novelBackgroundDark,
    int? recentItemsCap,
    Object? novelCacheCapMb = _unset,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      subtitlesByDefault: subtitlesByDefault ?? this.subtitlesByDefault,
      audioBackgroundPlayback:
          audioBackgroundPlayback ?? this.audioBackgroundPlayback,
      audioNotificationPersistent:
          audioNotificationPersistent ?? this.audioNotificationPersistent,
      novelWritingMode: novelWritingMode ?? this.novelWritingMode,
      novelFontSizeSp: novelFontSizeSp ?? this.novelFontSizeSp,
      novelLineHeight: novelLineHeight ?? this.novelLineHeight,
      novelFontFamily: novelFontFamily ?? this.novelFontFamily,
      novelBackgroundLight: novelBackgroundLight ?? this.novelBackgroundLight,
      novelBackgroundDark: novelBackgroundDark ?? this.novelBackgroundDark,
      recentItemsCap: recentItemsCap ?? this.recentItemsCap,
      novelCacheCapMb: identical(novelCacheCapMb, _unset)
          ? this.novelCacheCapMb
          : novelCacheCapMb as int?,
    );
  }

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.defaultPlaybackSpeed == defaultPlaybackSpeed &&
        other.subtitlesByDefault == subtitlesByDefault &&
        other.audioBackgroundPlayback == audioBackgroundPlayback &&
        other.audioNotificationPersistent == audioNotificationPersistent &&
        other.novelWritingMode == novelWritingMode &&
        other.novelFontSizeSp == novelFontSizeSp &&
        other.novelLineHeight == novelLineHeight &&
        other.novelFontFamily == novelFontFamily &&
        other.novelBackgroundLight == novelBackgroundLight &&
        other.novelBackgroundDark == novelBackgroundDark &&
        other.recentItemsCap == recentItemsCap &&
        other.novelCacheCapMb == novelCacheCapMb;
  }

  @override
  int get hashCode => Object.hash(
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
  );

  @override
  String toString() =>
      'AppSettings(themeMode: $themeMode, defaultPlaybackSpeed: '
      '$defaultPlaybackSpeed, subtitlesByDefault: $subtitlesByDefault, '
      'audioBackgroundPlayback: $audioBackgroundPlayback, '
      'audioNotificationPersistent: $audioNotificationPersistent, '
      'novelWritingMode: $novelWritingMode, novelFontSizeSp: '
      '$novelFontSizeSp, novelLineHeight: $novelLineHeight, '
      'novelFontFamily: $novelFontFamily, novelBackgroundLight: '
      '0x${novelBackgroundLight.toRadixString(16)}, novelBackgroundDark: '
      '0x${novelBackgroundDark.toRadixString(16)}, recentItemsCap: '
      '$recentItemsCap, novelCacheCapMb: $novelCacheCapMb)';
}
