## ADDED Requirements

### Requirement: PageSession supports local book progress

The system SHALL use `PageSession` for local book reading progress. PDF progress MUST be representable as a page index plus optional viewport state, and EPUB progress MUST be representable as a chapter or locator plus scroll fraction.

#### Scenario: Book session exposes progress

- **WHEN** a local book reader updates its current location
- **THEN** its `PageSession` exposes the updated `PagePosition` for persistence and resume

### Requirement: PageSession remains format-agnostic

The shared `PageSession` API SHALL NOT expose PDF-only or EPUB-only types. Format-specific locator details MUST be carried by book-domain value objects or serialized fields outside the shared media API.

#### Scenario: Shared media switch remains exhaustive

- **WHEN** the Dart analyzer evaluates switches over `MediaSession`
- **THEN** adding book reader support does not require a new `MediaSession` subtype beyond the existing page-oriented abstraction
