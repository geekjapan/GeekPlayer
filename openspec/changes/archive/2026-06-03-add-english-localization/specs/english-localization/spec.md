## ADDED Requirements

### Requirement: English locale is supported

The system SHALL support `Locale('en')` in addition to Japanese. Japanese SHALL remain the default fallback locale when the OS locale is unsupported or when an English translation key is missing during development.

#### Scenario: English locale is selected by the platform

- **WHEN** the platform locale is English
- **THEN** MaterialApp resolves `AppLocalizations` for `en` and supported screens render English copy

#### Scenario: Unsupported locale falls back to Japanese

- **WHEN** the platform locale is unsupported
- **THEN** MaterialApp resolves Japanese copy rather than showing missing-key placeholders

### Requirement: ARB keys have Japanese and English parity

Every key in `app/lib/l10n/app_ja.arb` SHALL have a corresponding key in `app/lib/l10n/app_en.arb`, excluding metadata-only `@key` entries that belong to the same translated key.

#### Scenario: ARB parity test passes

- **WHEN** the localization parity test loads both ARB files
- **THEN** the set of translatable keys is identical between Japanese and English

### Requirement: Shared UI surfaces use AppLocalizations

Shared navigation, settings, about, error, consent, and common reader-action copy SHALL be read from `AppLocalizations` instead of hard-coded strings.

#### Scenario: Settings renders English labels

- **WHEN** the Settings screen is pumped with `Locale('en')`
- **THEN** its section headings and common controls render English labels

#### Scenario: Settings renders Japanese labels

- **WHEN** the Settings screen is pumped with `Locale('ja')`
- **THEN** its section headings and common controls render Japanese labels

### Requirement: New v0.2 UI copy is localizable by default

Every v0.2 feature change after this one SHALL add new user-visible copy to ARB files and access it through generated localization getters.

#### Scenario: Future reader action is localized

- **WHEN** a later PDF/EPUB reader change adds a visible "bookmark" action
- **THEN** it adds Japanese and English ARB entries and uses `AppLocalizations` to render the label or semantics
