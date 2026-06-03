## ADDED Requirements

### Requirement: PageSession supports manga page progress

The system SHALL use `PageSession` for manga reading progress. Manga progress MUST be representable as a current page index or spread anchor plus scroll/viewport state stored outside the shared `MediaSession` subtype.

#### Scenario: Manga session exposes page progress

- **WHEN** a manga viewer changes the current page
- **THEN** its `PageSession` emits an updated `PagePosition` for persistence and resume

### Requirement: Manga support does not add a MediaSession subtype

The system SHALL NOT add a new `MangaSession` subtype to the `MediaSession` sealed hierarchy. Manga reading MUST use the existing page-oriented abstraction.

#### Scenario: MediaSession switches remain stable

- **WHEN** the Dart analyzer evaluates switches over `MediaSession`
- **THEN** manga support does not require a new exhaustive-switch branch beyond the existing page-oriented branch
