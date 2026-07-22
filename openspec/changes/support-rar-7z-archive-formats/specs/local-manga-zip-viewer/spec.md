## MODIFIED Requirements

### Requirement: User can open ZIP, CBZ, and 7z/CB7 manga archives

The system SHALL allow the user to choose a local `.zip`, `.cbz`, `.7z`, or `.cb7` archive from the OS file picker and open it in a Manga Viewer screen when the archive contains at least one supported image page. Unsupported extensions other than `.rar` and `.cbr` MUST be rejected with an `UnsupportedFormatError`. Any `.rar` or `.cbr` path MUST instead return a dedicated not-yet-supported error code/message that identifies Issue #69 and MUST NOT use the generic `UnsupportedFormatError` message.

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

- **WHEN** the user selects a file with an extension other than `.zip`, `.cbz`, `.7z`, or `.cb7` from the manga picker
- **THEN** the app shows a generic `UnsupportedFormatError` and does not open the Manga Viewer screen

#### Scenario: RAR/CBR archive is rejected with a clear not-yet-supported message

- **WHEN** the app attempts to open a `.rar` or `.cbr` path
- **THEN** the app shows the dedicated RAR/CBR not-yet-supported message referencing Issue #69 and does not open the Manga Viewer screen
