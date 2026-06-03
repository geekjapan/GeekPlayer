# app-settings Specification

## Purpose
TBD - created by archiving change add-app-settings. Update Purpose after archive.
## Requirements
### Requirement: Settings screen accessible from the home screen

The system SHALL provide a `SettingsScreen` reachable from the home screen via a
gear icon in the `AppBar`. The screen MUST be implemented at
`app/lib/features/settings/presentation/settings_screen.dart` and MUST present
its sections as a vertical Material 3 `ListView` in the following fixed order:
表示 / 再生 / 動画 / 音楽 / 小説 / ライブラリ / キャッシュ / オンラインサービス
/ R18 / About. The screen MUST be dismissible by the standard back affordance.

#### Scenario: Gear icon opens settings

- **GIVEN** the user is on the home screen
- **WHEN** the user taps the gear icon in the `AppBar`
- **THEN** the `SettingsScreen` is pushed onto the navigator and the 10 sections
  are rendered in the declared order

#### Scenario: Back returns to home

- **GIVEN** the `SettingsScreen` is the topmost route
- **WHEN** the user taps the system back button
- **THEN** the `SettingsScreen` is popped and the home screen is shown unchanged

### Requirement: Display section controls theme mode

The 表示 section SHALL expose a single radio-style control with the three
options `light` / `dark` / `system`. Selecting an option MUST update
`AppSettings.themeMode` immediately and MUST cause `MaterialApp.themeMode` to
reflect the new value across the running app within 100 ms. The アクセント
カラー row MUST be rendered as a disabled placeholder with a "v0.2 で対応"
trailing badge.

#### Scenario: Switching to dark mode is immediate

- **GIVEN** the app is running with `themeMode = light`
- **WHEN** the user selects `dark` in the 表示 section
- **THEN** `AppSettings.themeMode` becomes `dark`, every screen recolors within
  100 ms, and the new value is persisted to `app_settings`

#### Scenario: Accent color is locked

- **WHEN** the user taps the アクセントカラー row
- **THEN** the row is non-interactive, no dialog is shown, and a "v0.2 で対応"
  badge is visible on the trailing edge

### Requirement: Playback section sets default playback speed

The 再生 section SHALL provide a presets-only selector for default playback
speed with values 0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 1.75 / 2.0. The selected
value MUST be stored as `AppSettings.defaultPlaybackSpeed`. New media sessions
SHALL initialize their speed from this value; sessions already playing MUST
NOT be retroactively changed.

#### Scenario: New session adopts the default speed

- **GIVEN** the user sets default playback speed to 1.25x
- **WHEN** the user opens a video file from the home screen
- **THEN** the `PlayerScreen` starts at 1.25x

#### Scenario: Currently playing session is unaffected

- **GIVEN** a video is currently playing at 1.0x
- **WHEN** the user switches to the settings screen and changes default speed
  to 2.0x
- **THEN** the still-playing video remains at 1.0x until the user reopens it

### Requirement: Video section controls subtitle default

The 動画 section SHALL provide a single switch "字幕を最初から表示する" bound
to `AppSettings.subtitlesByDefault`. New video sessions SHALL honor this value
when selecting the initial subtitle track; sessions already running MUST NOT
change track.

#### Scenario: New video respects subtitle default

- **GIVEN** `subtitlesByDefault = true`
- **WHEN** the user opens a new video file with an embedded subtitle track
- **THEN** the first embedded subtitle track is shown immediately on playback
  start

### Requirement: Audio section controls background and notification

The 音楽 section SHALL provide two switches: "バックグラウンド再生" bound to
`AppSettings.audioBackgroundPlayback`, and "通知を継続表示" bound to
`AppSettings.audioNotificationPersistent`. Toggling either switch MUST take
effect immediately for any active or future audio session.

#### Scenario: Toggling background playback is immediate

- **GIVEN** an audio session is currently playing in the foreground
- **WHEN** the user toggles "バックグラウンド再生" OFF and switches to another
  app
- **THEN** the audio session pauses within 1 second

#### Scenario: Notification persistence is immediate

- **GIVEN** "通知を継続表示" is OFF and an audio session is playing
- **WHEN** the user toggles "通知を継続表示" ON
- **THEN** the OS media notification appears within 1 second and remains until
  the session ends or the toggle is switched OFF

### Requirement: Novel section controls reader appearance

The 小説 section SHALL allow the user to configure: writing mode (vertical /
horizontal), font size (sp, 12.0–32.0 in 1.0 step), line height (1.0–3.0 in
0.1 step), font family (initial choices: `noto-serif-jp` / `noto-sans-jp`),
and background color per theme (`novelBackgroundLight`, `novelBackgroundDark`).
Changes MUST be reflected immediately in any open novel reader screen.

#### Scenario: Font size slider updates reader live

- **GIVEN** the user has a novel reader screen open and the settings screen
  pushed on top
- **WHEN** the user drags the font size slider from 16 sp to 22 sp
- **THEN** the underlying novel reader rerenders with the new size, and the
  value is persisted after a 250 ms debounce

#### Scenario: Background color is theme-scoped

- **GIVEN** the system theme is `dark`
- **WHEN** the user picks a dark cream color in the 背景色 (ダーク) picker
- **THEN** `novelBackgroundDark` is updated, the reader applies it immediately,
  and `novelBackgroundLight` is NOT changed

### Requirement: Library section caps recent items and supports history clear

The ライブラリ section SHALL provide a single-select for "最近開いた" cap
with values 10 / 25 / 50 / 100 (default 50), and a destructive
"履歴をすべてクリア" button. Lowering the cap MUST NOT delete entries
immediately; the next time the home screen renders, the system MUST prune
`recent_items` down to the new cap. Tapping the clear button MUST present a
confirmation dialog and on confirm delete every row in `recent_items`.

#### Scenario: Lowering cap prunes on next home render

- **GIVEN** `recent_items` contains 80 rows and the user changes the cap from
  100 to 25
- **WHEN** the user navigates back to the home screen
- **THEN** `recent_items` contains exactly 25 rows (the most recent), and the
  list shows 25 entries

#### Scenario: History clear requires confirmation

- **WHEN** the user taps "履歴をすべてクリア"
- **THEN** a confirmation dialog appears with [削除する] [キャンセル], and only
  tapping [削除する] empties `recent_items`

### Requirement: Cache section shows size and supports clearing

The キャッシュ section SHALL display the current novel-body cache size in MB
computed from `SELECT SUM(LENGTH(body_html)) FROM novel_episodes`, a per-site
cap configurable as a positive integer of MB or "無制限" (default 無制限),
and clear buttons per `Site` plus a "すべてクリア" destructive button. While
the size is being computed, a `LinearProgressIndicator` MUST be shown in
place of the size value.

#### Scenario: Size shows progress then value

- **WHEN** the user opens the キャッシュ section
- **THEN** a `LinearProgressIndicator` is shown initially, replaced by the
  computed size string (e.g., "42.5 MB") within 2 seconds for caches under 10k
  episodes

#### Scenario: Exceeding cap shows a warning banner

- **GIVEN** the user has set the cap to 100 MB and the cache currently holds
  120 MB
- **WHEN** the キャッシュ section renders
- **THEN** a red banner appears reading "キャッシュが上限を超えています" with
  a button "古い順に削除する"; the system MUST NOT delete anything until the
  user taps that button

#### Scenario: Per-site clear is scoped

- **WHEN** the user taps "カクヨムのキャッシュをクリア" and confirms
- **THEN** every `novel_episodes` row with `site_id = 'kakuyomu'` is deleted,
  and `library_entries` rows are NOT touched

### Requirement: Online services section surfaces consent toggles and cache deletion prompt

The オンラインサービス section SHALL render one row per supported `Site`
(narou / noc / kakuyomu) showing the current consent state from
`SiteConsentRepository`, a switch to toggle consent, and the permanent
disclosure required by ADR-0001 §注意書き-3 above the rows. When the user
toggles a site from granted to revoked, the system MUST present a confirmation
dialog asking whether to also delete that site's body cache; the consent
update MUST proceed regardless of the cache choice, but body cache deletion
MUST only happen if the user confirms.

#### Scenario: Revoking kakuyomu offers cache deletion

- **GIVEN** the user has kakuyomu consent granted and 12 MB of kakuyomu body
  cache
- **WHEN** the user toggles kakuyomu consent OFF
- **THEN** `SiteConsentRepository.revoke(SiteId.kakuyomu)` is called, then a
  dialog appears with body "本文キャッシュ (12 MB) も削除しますか?" and
  buttons [削除する] [残す]

#### Scenario: Choosing "残す" leaves cache intact

- **GIVEN** the cache-deletion confirmation dialog is open after revoking
  kakuyomu
- **WHEN** the user taps "残す"
- **THEN** consent remains revoked, `novel_episodes` rows for kakuyomu are
  preserved, and the cache size shown in the キャッシュ section is unchanged

#### Scenario: Choosing "削除する" wipes the site cache

- **GIVEN** the cache-deletion confirmation dialog is open
- **WHEN** the user taps "削除する"
- **THEN** every `novel_episodes` row with `site_id = 'kakuyomu'` is deleted
  and the cache size shown in the キャッシュ section drops accordingly

### Requirement: R18 section provides age-gate reset

The R18 section SHALL display the current R18 consent state from the
`r18-age-gate` capability and provide a "年齢確認をやり直す" button. Tapping
the button MUST show a confirmation dialog; on confirm, the system MUST call
`SiteConsentRepository.revoke(SiteId.narou18)` and update the section to show
"未同意" without further navigation.

#### Scenario: Reset shows confirmation

- **GIVEN** R18 consent was granted on 2026-04-01
- **WHEN** the user taps "年齢確認をやり直す"
- **THEN** a dialog appears with [リセットする] [キャンセル], and only tapping
  [リセットする] calls `SiteConsentRepository.revoke(SiteId.narou18)`

#### Scenario: Reset updates the section live

- **GIVEN** the confirmation dialog is open and consent state is "同意済み"
- **WHEN** the user taps "リセットする"
- **THEN** the R18 section row immediately re-renders as "未同意" without
  leaving the settings screen

### Requirement: About section links to placeholder destinations

The About section SHALL render three rows: バージョン (showing the current
build's version string), ライセンス, and OSS Notices. Each row MUST be tappable
but MAY navigate to a placeholder screen labeled "未実装 (add-about-and-licenses)"
until that change lands. The version string row MUST display a non-placeholder
value sourced from `package_info_plus` or equivalent.

#### Scenario: Version row shows the live build version

- **WHEN** the user opens the About section
- **THEN** the バージョン row shows a non-empty version string matching
  `pubspec.yaml`'s `version:` field

#### Scenario: License rows route to placeholder

- **WHEN** the user taps the ライセンス row
- **THEN** a screen labeled "未実装 (add-about-and-licenses)" is pushed and can
  be popped to return to the settings screen

### Requirement: Realtime reflection policy is disclosed in the UI

For each setting whose policy is "next launch only" (per design D7), the
section row SHALL display a 1-line ja helper text in a smaller font under the
control reading "変更は次回起動から有効になります". For settings that reflect
immediately, no such helper is shown. The helper text MUST be present on:
default playback speed, default subtitle on/off.

#### Scenario: Default speed shows the next-launch helper

- **WHEN** the user opens the 再生 section
- **THEN** the default playback speed row displays the helper "変更は次回起動から
  有効になります" below the speed selector

#### Scenario: Font size has no helper

- **WHEN** the user opens the 小説 section
- **THEN** the font size slider row does NOT display the next-launch helper
  text, because font size reflects immediately

### Requirement: Settings screen supports English copy

All Settings screen section headings, row labels, option labels, badges, dialogs, and helper text SHALL render through localization and support Japanese and English.

#### Scenario: Settings placeholder badge is localized

- **WHEN** the Settings screen is pumped with `Locale('en')`
- **THEN** the v0.2 placeholder badge is displayed in English rather than the Japanese literal "v0.2 で対応"

### Requirement: Book reader defaults are configurable

The Settings screen SHALL expose book reader defaults for EPUB font size, EPUB line height, EPUB font family where supported, PDF initial zoom behavior, and whether to reopen the last position automatically. Defaults MUST be persisted via `AppSettings`.

#### Scenario: EPUB font size default applies to new reader

- **GIVEN** the user sets the EPUB font size default to 18sp
- **WHEN** the user opens an EPUB
- **THEN** the reader initially renders text at 18sp

### Requirement: Active reader setting propagation is defined

Each book setting SHALL define whether changes apply immediately to an open reader or only to newly opened readers.

#### Scenario: EPUB display setting updates active reader

- **WHEN** the user changes EPUB font size while an EPUB reader is open
- **THEN** the active reader updates according to the documented propagation model

### Requirement: Manga reader defaults are configurable

The Settings screen SHALL expose manga reader defaults for reading direction, single-page versus spread layout, and zoom reset behavior. Defaults MUST be persisted via `AppSettings`.

#### Scenario: Reading direction default applies to new viewer

- **GIVEN** the user sets manga reading direction to right-to-left
- **WHEN** the user opens a manga archive
- **THEN** the viewer initially uses right-to-left navigation and spread ordering

### Requirement: Active manga setting propagation is defined

Each manga setting SHALL define whether changes apply immediately to an open viewer or only to newly opened viewers.

#### Scenario: Spread mode updates according to policy

- **WHEN** the user changes the manga spread-mode setting while a manga viewer is open
- **THEN** the viewer behavior follows the documented propagation model for that setting

