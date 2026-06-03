## ADDED Requirements

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
