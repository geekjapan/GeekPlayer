## MODIFIED Requirements

### Requirement: User can open ZIP, CBZ, and 7z/CB7 manga archives

The system SHALL allow the user to choose a local `.zip`, `.cbz`, `.7z`, or `.cb7` archive from the OS file picker and open it in a Manga Viewer screen when the archive contains at least one supported image page. Unsupported extensions MUST be rejected with an `UnsupportedFormatError`. For `.rar` and `.cbr` files, the system MUST reject them with a distinct, user-facing message explaining that RAR/CBR support is not yet available (tracked separately) rather than a generic unsupported-format message.

#### Scenario: CBZ archive opens

- **WHEN** the user selects a readable `.cbz` archive containing image pages
- **THEN** the Manga Viewer screen opens and renders the first page or last saved position

#### Scenario: ZIP archive opens

- **WHEN** the user selects a readable `.zip` archive containing image pages
- **THEN** the Manga Viewer screen opens and renders the first page or last saved position

#### Scenario: 7z archive opens

- **WHEN** the user selects a readable `.7z` archive containing image pages
- **THEN** the Manga Viewer screen opens and renders the first page or last saved position

#### Scenario: CB7 archive opens

- **WHEN** the user selects a readable `.cb7` archive containing image pages
- **THEN** the Manga Viewer screen opens and renders the first page or last saved position

#### Scenario: Unsupported archive extension is rejected

- **WHEN** the user selects a file with an extension other than `.zip`, `.cbz`, `.7z`, `.cb7`, `.rar`, or `.cbr` from the manga picker
- **THEN** the app shows a generic `UnsupportedFormatError` and does not open the Manga Viewer screen

#### Scenario: RAR/CBR archive is rejected with a clear not-yet-supported message

- **WHEN** the user selects a `.rar` or `.cbr` file from the manga picker or attempts to open one by path
- **THEN** the app shows a distinct message indicating RAR/CBR is not yet supported (rather than a generic `UnsupportedFormatError` message) and does not open the Manga Viewer screen
