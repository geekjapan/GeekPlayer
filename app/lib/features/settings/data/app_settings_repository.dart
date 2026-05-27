import 'package:flutter/material.dart' show ThemeMode;
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/database.dart';
import '../../../core/storage/providers.dart';
import '../domain/app_settings.dart';
import '../domain/novel_writing_mode.dart';
import '../domain/setting_keys.dart';
import 'settings_codec.dart';

part 'app_settings_repository.g.dart';

/// Persists `AppSettings` against the EAV `app_settings` drift table.
///
/// Sole writer of the table — feature widgets MUST go through
/// `AppSettingsNotifier`, which holds a single instance of this class
/// per the spec `settings-persistence` Requirement "`app_settings`
/// drift table".
class AppSettingsRepository {
  AppSettingsRepository(this._dao, {Logger? logger})
    : _logger = logger ?? Logger(printer: SimplePrinter(printTime: false));

  final AppSettingsDao _dao;
  final Logger _logger;

  /// Returns a fully populated [AppSettings]. Missing keys resolve to the
  /// field's default. A decode failure for a single key falls back to the
  /// default for that key only and emits a warning log; other keys are
  /// unaffected.
  Future<AppSettings> readAll() async {
    final List<AppSettingRow> rows = await _dao.getAll();
    final Map<String, String> map = <String, String>{
      for (final AppSettingRow r in rows) r.key: r.value,
    };
    final AppSettings d = AppSettings.defaults();

    return AppSettings(
      themeMode: _decode<ThemeMode>(
        map,
        SettingKeys.themeMode,
        kThemeModeCodec,
        d.themeMode,
      ),
      defaultPlaybackSpeed: _decode<double>(
        map,
        SettingKeys.defaultPlaybackSpeed,
        kDoubleCodec,
        d.defaultPlaybackSpeed,
      ),
      subtitlesByDefault: _decode<bool>(
        map,
        SettingKeys.subtitlesByDefault,
        kBoolCodec,
        d.subtitlesByDefault,
      ),
      audioBackgroundPlayback: _decode<bool>(
        map,
        SettingKeys.audioBackgroundPlayback,
        kBoolCodec,
        d.audioBackgroundPlayback,
      ),
      audioNotificationPersistent: _decode<bool>(
        map,
        SettingKeys.audioNotificationPersistent,
        kBoolCodec,
        d.audioNotificationPersistent,
      ),
      novelWritingMode: _decode<NovelWritingMode>(
        map,
        SettingKeys.novelWritingMode,
        kNovelWritingModeCodec,
        d.novelWritingMode,
      ),
      novelFontSizeSp: _decode<double>(
        map,
        SettingKeys.novelFontSizeSp,
        kDoubleCodec,
        d.novelFontSizeSp,
      ),
      novelLineHeight: _decode<double>(
        map,
        SettingKeys.novelLineHeight,
        kDoubleCodec,
        d.novelLineHeight,
      ),
      novelFontFamily: _decode<String>(
        map,
        SettingKeys.novelFontFamily,
        kStringCodec,
        d.novelFontFamily,
      ),
      novelBackgroundLight: _decode<int>(
        map,
        SettingKeys.novelBackgroundLight,
        kIntCodec,
        d.novelBackgroundLight,
      ),
      novelBackgroundDark: _decode<int>(
        map,
        SettingKeys.novelBackgroundDark,
        kIntCodec,
        d.novelBackgroundDark,
      ),
      recentItemsCap: _decode<int>(
        map,
        SettingKeys.recentItemsCap,
        kIntCodec,
        d.recentItemsCap,
      ),
      novelCacheCapMb: _decode<int?>(
        map,
        SettingKeys.novelCacheCapMb,
        kNullableIntCodec,
        d.novelCacheCapMb,
      ),
    );
  }

  /// Compute the field-by-field diff and write only the changed keys in
  /// a single drift transaction. Throws if the transaction fails so the
  /// caller (AppSettingsNotifier) can revert in-memory state and surface
  /// the error via `AsyncError`.
  Future<void> writeDiff(AppSettings oldS, AppSettings newS) async {
    final Map<String, String> diff = _diffEncoded(oldS, newS);
    if (diff.isEmpty) return;
    await _dao.upsertAll(diff);
  }

  /// Convenience: persist every field of [snapshot] regardless of any
  /// "current" snapshot. Used by tests and one-shot bootstrap paths.
  Future<void> writeAll(AppSettings snapshot) async {
    await _dao.upsertAll(_encodeAll(snapshot));
  }

  // ---- private helpers --------------------------------------------------

  T _decode<T>(
    Map<String, String> map,
    String key,
    SettingCodec<T> codec,
    T fallback,
  ) {
    final String? raw = map[key];
    if (raw == null) return fallback;
    try {
      return codec.decode(raw);
    } on FormatException catch (e) {
      _logger.w(
        'AppSettingsRepository: malformed value for "$key" '
        '(raw="$raw"); falling back to default. Error: ${e.message}',
      );
      return fallback;
    }
  }

  Map<String, String> _diffEncoded(AppSettings o, AppSettings n) {
    final Map<String, String> out = <String, String>{};
    if (o.themeMode != n.themeMode) {
      out[SettingKeys.themeMode] = kThemeModeCodec.encode(n.themeMode);
    }
    if (o.defaultPlaybackSpeed != n.defaultPlaybackSpeed) {
      out[SettingKeys.defaultPlaybackSpeed] = kDoubleCodec.encode(
        n.defaultPlaybackSpeed,
      );
    }
    if (o.subtitlesByDefault != n.subtitlesByDefault) {
      out[SettingKeys.subtitlesByDefault] = kBoolCodec.encode(
        n.subtitlesByDefault,
      );
    }
    if (o.audioBackgroundPlayback != n.audioBackgroundPlayback) {
      out[SettingKeys.audioBackgroundPlayback] = kBoolCodec.encode(
        n.audioBackgroundPlayback,
      );
    }
    if (o.audioNotificationPersistent != n.audioNotificationPersistent) {
      out[SettingKeys.audioNotificationPersistent] = kBoolCodec.encode(
        n.audioNotificationPersistent,
      );
    }
    if (o.novelWritingMode != n.novelWritingMode) {
      out[SettingKeys.novelWritingMode] = kNovelWritingModeCodec.encode(
        n.novelWritingMode,
      );
    }
    if (o.novelFontSizeSp != n.novelFontSizeSp) {
      out[SettingKeys.novelFontSizeSp] = kDoubleCodec.encode(n.novelFontSizeSp);
    }
    if (o.novelLineHeight != n.novelLineHeight) {
      out[SettingKeys.novelLineHeight] = kDoubleCodec.encode(n.novelLineHeight);
    }
    if (o.novelFontFamily != n.novelFontFamily) {
      out[SettingKeys.novelFontFamily] = kStringCodec.encode(n.novelFontFamily);
    }
    if (o.novelBackgroundLight != n.novelBackgroundLight) {
      out[SettingKeys.novelBackgroundLight] = kIntCodec.encode(
        n.novelBackgroundLight,
      );
    }
    if (o.novelBackgroundDark != n.novelBackgroundDark) {
      out[SettingKeys.novelBackgroundDark] = kIntCodec.encode(
        n.novelBackgroundDark,
      );
    }
    if (o.recentItemsCap != n.recentItemsCap) {
      out[SettingKeys.recentItemsCap] = kIntCodec.encode(n.recentItemsCap);
    }
    if (o.novelCacheCapMb != n.novelCacheCapMb) {
      out[SettingKeys.novelCacheCapMb] = kNullableIntCodec.encode(
        n.novelCacheCapMb,
      );
    }
    return out;
  }

  Map<String, String> _encodeAll(AppSettings s) {
    return _diffEncoded(_invertedDefaults(s), s);
  }

  // Used by writeAll: build a "previous" snapshot that differs from s in
  // every field so the diff captures every key.
  AppSettings _invertedDefaults(AppSettings s) {
    return AppSettings(
      themeMode: s.themeMode == ThemeMode.system
          ? ThemeMode.light
          : ThemeMode.system,
      defaultPlaybackSpeed: -s.defaultPlaybackSpeed - 1,
      subtitlesByDefault: !s.subtitlesByDefault,
      audioBackgroundPlayback: !s.audioBackgroundPlayback,
      audioNotificationPersistent: !s.audioNotificationPersistent,
      novelWritingMode:
          s.novelWritingMode == NovelWritingMode.vertical
              ? NovelWritingMode.horizontal
              : NovelWritingMode.vertical,
      novelFontSizeSp: -s.novelFontSizeSp - 1,
      novelLineHeight: -s.novelLineHeight - 1,
      novelFontFamily: '__force_diff__',
      novelBackgroundLight: ~s.novelBackgroundLight,
      novelBackgroundDark: ~s.novelBackgroundDark,
      recentItemsCap: -s.recentItemsCap - 1,
      novelCacheCapMb: s.novelCacheCapMb == null
          ? 0
          : (s.novelCacheCapMb! + 1) * -1 - 1,
    );
  }
}

@Riverpod(keepAlive: true)
AppSettingsRepository appSettingsRepository(Ref ref) {
  return AppSettingsRepository(ref.watch(appSettingsDaoProvider));
}
