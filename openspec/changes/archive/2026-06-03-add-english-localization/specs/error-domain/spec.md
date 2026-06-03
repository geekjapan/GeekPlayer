## ADDED Requirements

### Requirement: Errors have English localized messages

Every `AppError` variant that has Japanese localization SHALL also have English localization. Error localization MUST continue to fall back to the raw error message when no localization context is available.

#### Scenario: Error localizes in English

- **WHEN** `ErrorMessages.localize` is called for each declared `AppError` variant under `Locale('en')`
- **THEN** every call returns a non-empty English string and no call throws
