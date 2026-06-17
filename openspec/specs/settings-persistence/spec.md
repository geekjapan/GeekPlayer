# settings-persistence Specification

## Purpose
TBD - created by archiving change add-app-settings. Update Purpose after archive.
## Requirements
### Requirement: `app_settings` drift table

The system SHALL define a drift table named `app_settings` at
`app/lib/core/storage/tables/app_settings.dart` with exactly two columns:
`key TEXT NOT NULL PRIMARY KEY` and `value TEXT NOT NULL`. The table MUST be
registered with the shared `@DriftDatabase` declared at
`app/lib/core/storage/database.dart`. Rows MUST be inserted, read, and updated
exclusively through `AppSettingsRepository`; no other class MAY issue raw
SQL against this table.

#### Scenario: Table is created on fresh install

- **GIVEN** a brand new install with no existing database file
- **WHEN** the app initializes drift
- **THEN** the `app_settings` table exists with the `key` / `value` columns and
  contains zero rows

#### Scenario: Direct SQL access is unavailable outside the repository

- **WHEN** a static-analysis lint checks for `SELECT * FROM app_settings`
  outside `app/lib/features/settings/data/`
- **THEN** the lint reports zero matches

### Requirement: drift schema version reaches 3 via additive migrations

The drift `@DriftDatabase.schemaVersion` SHALL be set to `3` in this change.
`MigrationStrategy.onUpgrade` MUST contain explicit branches handling the
transitions `from < 2` (novel-library tables, owned by
`add-online-novel-library`) and `from < 3` (this change's `app_settings` table).
The branches MUST be additive: they MUST create new tables only and MUST NOT
drop or alter any existing table.

#### Scenario: Fresh install starts at v3

- **GIVEN** a fresh install
- **WHEN** drift initializes
- **THEN** `schemaVersion` is `3` and `onCreate` creates all v1, v2, and v3
  tables in one transaction

#### Scenario: v1 → v3 skip migration runs both branches

- **GIVEN** a database file with `schemaVersion = 1` containing
  `playback_positions` and `recent_items` rows
- **WHEN** drift opens the database with `schemaVersion = 3`
- **THEN** `onUpgrade` runs the `from < 2` branch (creates novel-library
  tables) then the `from < 3` branch (creates `app_settings`), and all
  pre-existing `playback_positions` / `recent_items` rows remain intact

#### Scenario: v2 → v3 runs only the v3 branch

- **GIVEN** a database file with `schemaVersion = 2`
- **WHEN** drift opens the database with `schemaVersion = 3`
- **THEN** `onUpgrade` runs only the `from < 3` branch, creating
  `app_settings`; no other table is modified

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

### Requirement: `SettingCodec<T>` provides type-safe encoding

The system SHALL define a generic `SettingCodec<T>` interface at
`app/lib/features/settings/data/settings_codec.dart` with `String encode(T)`
and `T decode(String)` methods. Concrete codecs MUST be provided for `bool`,
`int`, `double`, nullable `int?`, and each enum type used by `AppSettings`
(`ThemeMode`, `NovelWritingMode`). Decoding MUST throw `FormatException` on
malformed input.

#### Scenario: Bool roundtrips through `true`/`false` strings

- **WHEN** `BoolCodec().encode(true)` and `BoolCodec().decode('true')` are
  called
- **THEN** the encode returns the string `"true"` and the decode returns
  `true`; encoding `false` yields `"false"` and decoding `"false"` yields
  `false`

#### Scenario: Nullable int encodes null distinctly

- **WHEN** `NullableIntCodec().encode(null)` is called
- **THEN** the encoded value is the literal string `"null"`, and
  `NullableIntCodec().decode("null")` returns `null`

#### Scenario: Malformed input raises FormatException

- **WHEN** `DoubleCodec().decode("not-a-number")` is called
- **THEN** a `FormatException` is thrown synchronously

### Requirement: Repository hydrates AppSettings with defaults fallback

The `AppSettingsRepository.readAll()` method SHALL return a fully populated
`AppSettings` instance even when `app_settings` is empty or contains
malformed values. Missing keys MUST resolve to the field's default. Decode
failures MUST fall back to the default for that key and SHALL emit a
structured warning log including the offending key.

#### Scenario: Empty table returns defaults

- **GIVEN** `app_settings` has zero rows
- **WHEN** `AppSettingsRepository.readAll()` resolves
- **THEN** the returned `AppSettings` equals `AppSettings.defaults()`

#### Scenario: Single malformed row falls back to default for that key only

- **GIVEN** `app_settings` contains the rows
  `('novel.font_size_sp', 'NOT_A_NUMBER')` and
  `('theme.mode', 'dark')`
- **WHEN** `AppSettingsRepository.readAll()` resolves
- **THEN** `novelFontSizeSp == 16.0` (default) and `themeMode == dark`, and a
  warning log entry mentioning `novel.font_size_sp` is emitted

### Requirement: AppSettingsNotifier persists changes with debounced writes

The Riverpod `AppSettingsNotifier` SHALL update its in-memory state
synchronously on every `update(...)` call, and SHALL persist diffs to
`app_settings` via `AppSettingsRepository.writeDiff` with a 250 ms debounce
per `key`. On `dispose`, the notifier MUST flush any pending debounced writes
before releasing resources.

#### Scenario: Rapid slider updates coalesce to one write per key

- **GIVEN** the user drags the font size slider, triggering `update` calls at
  16, 17, 18, ..., 22 within 100 ms
- **WHEN** the user releases the slider
- **THEN** `state` reflects 22 immediately, and exactly one
  `AppSettingsRepository.writeDiff` call carrying `novelFontSizeSp = 22.0`
  fires approximately 250 ms after the last `update`

#### Scenario: Dispose flushes pending writes

- **GIVEN** an `update` was issued 50 ms ago and the debounce timer has not
  fired
- **WHEN** the notifier is disposed (e.g., during app shutdown)
- **THEN** the pending diff is written to `app_settings` synchronously before
  dispose returns

### Requirement: Setting keys are namespaced and stable

The set of keys written to `app_settings` SHALL be declared as a `const` map
in `app/lib/features/settings/domain/setting_keys.dart` using
dotted-namespace strings (e.g., `'theme.mode'`, `'playback.default_speed'`,
`'novel.font_size_sp'`, `'library.recent_cap'`, `'cache.cap_mb'`). Once a key
ships in a release, the literal string SHALL NOT be renamed; renames MUST be
handled by a new key + migration that copies the old value over.

#### Scenario: Keys are dotted-namespace strings

- **WHEN** `SettingKeys.all` is enumerated
- **THEN** every entry matches the regex `^[a-z][a-z_]*(\.[a-z][a-z_]*)+$`

#### Scenario: Renaming a key requires migration

- **GIVEN** a previously shipped key `'novel.font_size_sp'`
- **WHEN** the developer renames the constant to `'novel.font_size_px'`
- **THEN** the change MUST include an `onUpgrade` step that copies the value
  from the old key to the new key and deletes the old row

### Requirement: Write path is transactional

`AppSettingsRepository.writeDiff(old, new)` SHALL compare the two snapshots
field-by-field and write only the changed keys, all within a single drift
transaction. If the transaction fails, the in-memory state held by
`AppSettingsNotifier` MUST revert to the prior snapshot and the failure MUST
be surfaced to the caller via an `AsyncError` on the notifier.

#### Scenario: Partial failure rolls back

- **GIVEN** an `update` call that changes 3 keys
- **WHEN** drift's transaction fails on the second key (simulated)
- **THEN** none of the 3 keys is persisted, `state` reverts to the prior
  `AppSettings`, and the notifier emits `AsyncError`

#### Scenario: Only changed keys are written

- **GIVEN** `old` and `new` differ only in `themeMode`
- **WHEN** `writeDiff(old, new)` runs
- **THEN** the drift transaction issues exactly one upsert against
  `app_settings` (for `'theme.mode'`), not one per field

### Requirement: v0.2 settings changes name their runtime propagation model

Every v0.2 change that adds or consumes an `AppSettings` value SHALL define whether the value applies only to new sessions or updates currently active sessions. The implementation MUST use Riverpod subscriptions consistently with that decision.

#### Scenario: Reader setting declares propagation behavior

- **WHEN** a v0.2 reader setting is proposed
- **THEN** its design states whether changing the setting affects the open reader immediately or only the next opened document

### Requirement: Settings-facing copy participates in localization

Every new v0.2 settings label, section heading, placeholder, and dialog string SHALL use the localization system rather than a raw UI literal.

#### Scenario: New settings row is localizable

- **WHEN** a developer adds a settings row in a v0.2 change
- **THEN** the row label has Japanese and English localization entries

