# manga-archive-safety Specification

## Purpose
Defines how local manga archives (ZIP/CBZ) are inspected and validated before rendering, ensuring entries are read without unsafe extraction, only supported image formats are treated as pages, page ordering is deterministic across platforms, and resource limits guard against exhaustion.

## Requirements
### Requirement: Archive entries are inspected safely

The system SHALL inspect ZIP/CBZ entries without extracting them to arbitrary filesystem paths. Entries with absolute paths, `..` path traversal, hidden metadata directories, macOS resource forks, or directory-only records MUST NOT be treated as image pages.

#### Scenario: Path traversal entry is ignored

- **GIVEN** an archive contains an entry named `../evil.jpg`
- **WHEN** the archive is inspected
- **THEN** that entry is ignored and no file is written outside the app-controlled cache

### Requirement: Supported image formats are explicit

The system SHALL treat only `.jpg`, `.jpeg`, `.png`, `.webp`, and `.gif` entries as candidate manga pages. Unsupported entries MUST be ignored unless the archive contains no supported image entries.

#### Scenario: Archive with mixed files uses only images

- **GIVEN** an archive contains `001.jpg`, `notes.txt`, and `002.png`
- **WHEN** the archive page list is built
- **THEN** only `001.jpg` and `002.png` are included as pages

#### Scenario: Archive with no image pages fails clearly

- **WHEN** the user opens an archive containing no supported image entries
- **THEN** the app surfaces an unsupported-format or archive-content error and does not open the viewer

### Requirement: Page ordering is deterministic

The system SHALL sort candidate image entries using natural filename ordering inside their archive path. Sorting MUST be deterministic across platforms.

#### Scenario: Natural ordering handles numeric names

- **GIVEN** an archive contains `1.jpg`, `10.jpg`, and `2.jpg`
- **WHEN** the page list is built
- **THEN** the order is `1.jpg`, `2.jpg`, `10.jpg`

### Requirement: Archive size limits prevent resource exhaustion

The system SHALL enforce configured limits for entry count, total uncompressed bytes, single-entry uncompressed bytes, and decoded image dimensions before rendering pages.

#### Scenario: Oversized archive is rejected

- **WHEN** an archive exceeds the configured total uncompressed byte limit
- **THEN** the app rejects it with a localized error and does not decode image pages
