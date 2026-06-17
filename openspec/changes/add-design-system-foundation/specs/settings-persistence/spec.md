## MODIFIED Requirements

### Requirement: `AppSettings` value object with typed fields and defaults

The system SHALL define an immutable `AppSettings` value object in
`app/lib/features/settings/domain/app_settings.dart` with the following typed
fields and default values:

- `themeMode: ThemeMode.dark`
- `defaultPlaybackSpeed: 1.0` (double)
- `subtitlesByDefault: false`
- `audioBackgroundPlayback: true`
- `audioNotificationPersistent: true`
- `novelWritingMode: NovelWritingMode.vertical`
- `novelFontSizeSp: 16.0`
- `novelLineHeight: 1.7`
- `novelFontFamily: 'noto-serif-jp'`
- `novelBackgroundLight: 0xFFFAF7EE`
- `novelBackgroundDark: 0xFF1C1B1F`
- `recentItemsCap: 50`
- `novelCacheCapMb: null` (null = 無制限)

`themeMode` defaults to `ThemeMode.dark` so a fresh install opens in the dark,
content-forward theme (a media player is predominantly used in dim conditions
and the video/manga surfaces are already dark); users MAY switch to `system`
or `light` in settings.

`AppSettings` MUST expose a `.defaults()` constructor returning the above
values, and a `.copyWith(...)` that returns a new instance with the requested
overrides.

#### Scenario: Defaults match the documented values

- **WHEN** `AppSettings.defaults()` is invoked
- **THEN** every field equals exactly the value listed above

#### Scenario: copyWith produces a new instance

- **GIVEN** `final a = AppSettings.defaults();`
- **WHEN** `final b = a.copyWith(novelFontSizeSp: 22.0);`
- **THEN** `b.novelFontSizeSp == 22.0`, every other field equals `a`'s value,
  and `identical(a, b) == false`
