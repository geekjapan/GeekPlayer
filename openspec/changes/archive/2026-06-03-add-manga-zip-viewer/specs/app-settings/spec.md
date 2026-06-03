## ADDED Requirements

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
