## ADDED Requirements

### Requirement: Folder scan indexes local media files

The system SHALL scan one or more user-nominated folders using `dart:io` and insert or update rows in the `media_index` table for every discovered video and audio file.

Supported video extensions: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`.
Supported audio extensions: `.mp3`, `.flac`, `.aac`, `.wav`, `.ogg`, `.m4a`, `.opus`.

#### Scenario: Scanning a folder adds media items to the index

- **WHEN** the user triggers a folder scan
- **THEN** every supported media file in that folder (recursively) is inserted or updated in `media_index`
- **AND** unsupported files are silently skipped

### Requirement: Watch/play history is persisted per item

The system SHALL upsert a row in `watch_history` each time an indexed item is played, recording `last_played_at`, `position_ms`, `duration_ms`, and a `completed` boolean.

#### Scenario: Replaying an item updates history

- **GIVEN** a media item has been played once
- **WHEN** the user plays it again to completion
- **THEN** `watch_history.completed` is `true` and `last_played_at` is updated

### Requirement: Favorites can be toggled

The system SHALL allow users to mark or unmark any media item as a favorite. A row in the `favorites` table represents a favorited item; its absence means not favorited.

#### Scenario: Toggling favorite adds and removes the row

- **GIVEN** an item is not favorited
- **WHEN** the user stars the item
- **THEN** a row appears in `favorites`
- **WHEN** the user stars it again
- **THEN** the row is deleted

### Requirement: Playlists can be created and managed

The system SHALL allow users to create named playlists, add media items to them with an ordered position, reorder items, and delete playlists. Deleting a playlist MUST cascade-delete its `playlist_items` rows.

#### Scenario: Creating a playlist and adding items

- **GIVEN** no playlists exist
- **WHEN** the user creates a playlist named "Workout"
- **AND** adds two media items to it
- **THEN** `playlists` has one row and `playlist_items` has two rows with positions 0 and 1

### Requirement: Media library tables are added via drift schema v6

The system SHALL add `media_index`, `watch_history`, `favorites`, `playlists`, and `playlist_items` tables through drift schema version 6. Migration from v5 to v6 MUST preserve all existing rows in `playback_positions`, `recent_items`, `novel_works`, `novel_episodes`, `novel_bookmarks`, `site_consents`, `app_settings`, `book_metadata`, `book_bookmarks`, `manga_metadata`, and `manga_bookmarks`.

#### Scenario: v5 to v6 migration preserves existing data

- **GIVEN** a v5 database containing rows across all prior tables
- **WHEN** the database opens with schema version 6
- **THEN** all new media library tables are created and all pre-existing rows remain intact

### Requirement: Media library section appears on the home screen

The system SHALL contribute a `MediaLibraryHomeSection` through the home-section registry at ADR-0004 order 700. The section SHALL show recently played items and provide an entry point to trigger a folder scan.

#### Scenario: Recently played item appears in the section

- **GIVEN** the user played a media item from the library
- **WHEN** the home screen is displayed
- **THEN** the MediaLibraryHomeSection includes that item in the recent list
