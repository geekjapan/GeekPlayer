## ADDED Requirements

### Requirement: Settings screen supports English copy

All Settings screen section headings, row labels, option labels, badges, dialogs, and helper text SHALL render through localization and support Japanese and English.

#### Scenario: Settings placeholder badge is localized

- **WHEN** the Settings screen is pumped with `Locale('en')`
- **THEN** the v0.2 placeholder badge is displayed in English rather than the Japanese literal "v0.2 で対応"
