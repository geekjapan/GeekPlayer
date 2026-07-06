## MODIFIED Requirements

### Requirement: Archive entries are inspected safely

The system SHALL inspect ZIP/CBZ and 7z/CB7 entries without extracting them to arbitrary filesystem paths, regardless of container format. Entries with absolute paths, `..` path traversal, hidden metadata directories, macOS resource forks, or directory-only records MUST NOT be treated as image pages in any supported archive format.

#### Scenario: Path traversal entry is ignored (ZIP/CBZ)

- **GIVEN** a ZIP/CBZ archive contains an entry named `../evil.jpg`
- **WHEN** the archive is inspected
- **THEN** that entry is ignored and no file is written outside the app-controlled cache

#### Scenario: Path traversal entry is ignored (7z/CB7)

- **GIVEN** a 7z/CB7 archive contains an entry named `../evil.jpg`
- **WHEN** the archive is inspected
- **THEN** that entry is ignored and no file is written outside the app-controlled cache

### Requirement: Archive size limits prevent resource exhaustion

The system SHALL enforce configured limits for entry count, total uncompressed bytes, single-entry uncompressed bytes, and decoded image dimensions before rendering pages, regardless of container format. For formats whose compression scheme can achieve very high compression ratios (such as 7z/LZMA), the system MUST NOT rely solely on the container's declared uncompressed-size header; it MUST also track actual bytes produced while streaming-decompressing each entry and abort extraction immediately if the running total exceeds the configured single-entry or total limits, even if the declared header size was understated or falsified.

#### Scenario: Oversized archive is rejected by declared size

- **WHEN** an archive exceeds the configured total uncompressed byte limit according to its declared header sizes
- **THEN** the app rejects it with a localized error and does not decode image pages

#### Scenario: Declared-size-spoofed 7z entry is rejected during extraction

- **GIVEN** a 7z/CB7 archive entry declares an uncompressed size within limits but actually decompresses to more bytes than declared
- **WHEN** the entry is streamed for extraction
- **THEN** extraction is aborted as soon as the actual decompressed byte count exceeds the configured single-entry or total uncompressed byte limit, and the app surfaces a localized error instead of continuing to decode
