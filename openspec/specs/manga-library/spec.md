# manga-library Specification

## Purpose
Defines how local manga archives are catalogued and surfaced: persisting archive metadata, contributing a recent-manga home section, storing per-archive bookmarks separately from other media, and introducing the drift schema version 5 that backs these tables.

## Requirements
### Requirement: Manga archive metadata is persisted

The system SHALL persist local manga archive metadata including normalized URI, display title, format, file size, last modified timestamp, page count, cover page reference when available, created timestamp, and last opened timestamp.

#### Scenario: Opening an archive stores metadata

- **WHEN** the user opens a ZIP or CBZ archive for the first time
- **THEN** a manga metadata row is inserted or updated with file identity, display metadata, page count, and last opened timestamp

### Requirement: Recent manga appears on the home screen

The system SHALL contribute a `MangaHomeSection` through the home-section registry using the reserved manga order. The section SHALL show recent manga archives ordered by last opened time and SHALL allow reopening an entry.

#### Scenario: Recent manga is listed

- **GIVEN** the user opened a CBZ archive
- **WHEN** the home screen is displayed
- **THEN** the MangaHomeSection includes that archive before older manga entries

### Requirement: Manga bookmarks are persisted

The system SHALL let the user create, list, jump to, and delete bookmarks for local manga archives. Manga bookmarks MUST be stored separately from book bookmarks and online novel bookmarks.

#### Scenario: Bookmark survives restart

- **GIVEN** the user creates a bookmark on manga page 8
- **WHEN** the app restarts and the same archive is opened
- **THEN** the bookmark is available and navigates to page 8

### Requirement: Manga tables are added via drift schema v5

The system SHALL add manga metadata and bookmark tables through drift schema version 5 when `add-pdf-epub-reader` has already introduced schema version 4. Migration from v4 to v5 MUST preserve all existing playback, novel, consent, settings, and book data.

#### Scenario: v4 to v5 migration preserves existing data

- **GIVEN** a v4 database containing playback, novel, consent, settings, and book rows
- **WHEN** the database opens with schema version 5
- **THEN** manga tables are created and all pre-existing rows remain intact
