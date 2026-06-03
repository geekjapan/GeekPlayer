## ADDED Requirements

### Requirement: Book metadata is persisted

The system SHALL persist local book metadata including normalized URI, title, author when available, format, file size, last modified timestamp, created timestamp, and last opened timestamp.

#### Scenario: Opening a book stores metadata

- **WHEN** the user opens a PDF or EPUB for the first time
- **THEN** a book metadata row is inserted or updated with the file identity and display metadata

### Requirement: Recent books appear on the home screen

The system SHALL contribute a `BookHomeSection` through the home-section registry. The section SHALL show recent books ordered by last opened time and SHALL allow reopening an entry.

#### Scenario: Recent book is listed

- **GIVEN** the user opened an EPUB
- **WHEN** the home screen is displayed
- **THEN** the BookHomeSection includes that EPUB before older book entries

### Requirement: Book bookmarks are persisted

The system SHALL let the user create, list, jump to, and delete bookmarks for local books. Book bookmarks MUST be stored separately from online novel bookmarks.

#### Scenario: Bookmark survives restart

- **GIVEN** the user creates a bookmark in a PDF
- **WHEN** the app restarts and the same PDF is opened
- **THEN** the bookmark is available and navigates to the saved location

### Requirement: Book tables are added via drift schema v4

The system SHALL add book metadata and bookmark tables through drift schema version 4. Migration from v3 to v4 MUST preserve all existing playback, novel, consent, and settings data.

#### Scenario: v3 to v4 migration preserves existing data

- **GIVEN** a v3 database containing video, audio, novel, consent, and app_settings rows
- **WHEN** the database opens with schema version 4
- **THEN** book tables are created and all pre-existing rows remain intact
