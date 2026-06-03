# local-manga-zip-viewer Specification

## Purpose
Defines the Manga Viewer reading experience for local ZIP and CBZ archives: opening archives from the OS file picker, configurable reading direction, single-page and spread layouts, zoom and pan, and resuming the last reading position.

## Requirements
### Requirement: User can open ZIP and CBZ manga archives

The system SHALL allow the user to choose a local `.zip` or `.cbz` archive from the OS file picker and open it in a Manga Viewer screen when the archive contains at least one supported image page. Unsupported extensions MUST be rejected with an `UnsupportedFormatError`.

#### Scenario: CBZ archive opens

- **WHEN** the user selects a readable `.cbz` archive containing image pages
- **THEN** the Manga Viewer screen opens and renders the first page or last saved position

#### Scenario: ZIP archive opens

- **WHEN** the user selects a readable `.zip` archive containing image pages
- **THEN** the Manga Viewer screen opens and renders the first page or last saved position

#### Scenario: Unsupported archive extension is rejected

- **WHEN** the user selects a `.rar` file from the manga picker
- **THEN** the app shows an `UnsupportedFormatError` and does not open the Manga Viewer screen

### Requirement: Manga viewer supports reading direction

The Manga Viewer SHALL support right-to-left and left-to-right reading direction. Navigation gestures, next/previous buttons, and spread ordering MUST follow the selected direction.

#### Scenario: Right-to-left next advances visually left

- **GIVEN** reading direction is right-to-left
- **WHEN** the user performs the next-page gesture
- **THEN** the reader advances to the next logical page and presents spreads in right-to-left order

#### Scenario: Left-to-right next advances visually right

- **GIVEN** reading direction is left-to-right
- **WHEN** the user performs the next-page gesture
- **THEN** the reader advances to the next logical page and presents spreads in left-to-right order

### Requirement: Manga viewer supports single and spread layout

The Manga Viewer SHALL support single-page mode and two-page spread mode. Spread mode MUST handle odd page counts deterministically and MUST NOT skip pages.

#### Scenario: Spread mode with odd page count preserves all pages

- **GIVEN** an archive has 5 image pages
- **WHEN** the user reads in spread mode from start to end
- **THEN** all 5 pages are shown exactly once across the sequence

### Requirement: Manga viewer supports zoom and pan

The Manga Viewer SHALL support pinch zoom and pan for the currently visible page or spread. Moving to another page MUST apply the configured zoom reset behavior from settings.

#### Scenario: Pinch zoom changes scale

- **WHEN** the user pinches on a manga page
- **THEN** the visible image scale changes without changing the current page index

### Requirement: Manga viewer resumes last position

The Manga Viewer SHALL persist and restore the current page or spread anchor for each archive.

#### Scenario: Manga resumes saved page

- **GIVEN** the user previously closed an archive on page 23
- **WHEN** the same archive is opened again
- **THEN** the Manga Viewer restores page 23 before user interaction
