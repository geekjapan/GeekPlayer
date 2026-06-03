## ADDED Requirements

### Requirement: Manga viewer maps failures to AppError

The manga viewer SHALL surface missing files, unsupported archive formats, corrupt archives, unsafe archive entries, oversized archives, unsupported image formats, image decode failures, and storage failures as `AppError` variants before crossing into presentation code.

#### Scenario: Corrupt archive is surfaced as localized error

- **WHEN** the user opens a corrupt ZIP archive
- **THEN** the viewer shows a localized archive error and no raw archive exception reaches the widget tree

#### Scenario: Missing manga file is surfaced as file-not-found

- **WHEN** the user opens a stored manga entry whose archive no longer exists
- **THEN** the app surfaces `FileNotFoundError` with the missing URI
