## ADDED Requirements

### Requirement: Book reader maps failures to AppError

The book reader SHALL surface file-not-found, unsupported-format, parse/render, and storage failures as `AppError` variants before crossing into presentation code.

#### Scenario: Corrupt EPUB is surfaced as a parse error

- **WHEN** the user opens a corrupt EPUB file
- **THEN** the reader shows a localized parse/render error and no raw parser exception reaches the widget tree

#### Scenario: Missing PDF is surfaced as file-not-found

- **WHEN** the user opens a stored PDF entry whose file no longer exists
- **THEN** the app surfaces `FileNotFoundError` with the missing URI
