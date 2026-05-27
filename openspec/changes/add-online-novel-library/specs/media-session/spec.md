## ADDED Requirements

### Requirement: PageSession variant of MediaSession for reader feature

The system SHALL provide a `PageSession` concrete implementation of the `MediaSession` sealed type at `app/lib/core/media/page_session.dart` so that the home screen can render "in-progress" novel reading alongside in-progress video/audio uniformly. `PageSession` MUST be declared with `part of 'media_session.dart';` to satisfy the Dart 3 sealed-class same-library constraint (see GRILL-REPORT Q-CROSS-011).

#### Scenario: PageSession is a valid MediaSession variant

- **WHEN** a switch expression over `MediaSession` lists `case VideoSession()`, `case AudioSession()`, and `case PageSession()`
- **THEN** the analyzer accepts the switch as exhaustive

#### Scenario: PageSession can be observed for reading progress

- **WHEN** a `PageSession` is constructed for an opened novel episode and an observer subscribes to `pagePositionStream`
- **THEN** the stream emits at least one initial `PagePosition` value within 500 ms and continues to emit values whenever the user scrolls or navigates between episodes

### Requirement: PagePosition value object

The system SHALL define `PagePosition` as an immutable value object in `app/lib/core/media/page_session.dart` (same library) with `int pageIndex` (>=1) and `double scrollFraction` (0.0..1.0). The constructor MUST validate the ranges and throw `ArgumentError` on violation.

#### Scenario: Invalid PagePosition throws

- **WHEN** `PagePosition(pageIndex: 0, scrollFraction: 0.5)` is constructed
- **THEN** an `ArgumentError` is thrown

#### Scenario: scrollFraction out of range throws

- **WHEN** `PagePosition(pageIndex: 1, scrollFraction: 1.5)` is constructed
- **THEN** an `ArgumentError` is thrown

### Requirement: PageSession re-interprets MediaSession audio-centric methods

The `play` / `pause` methods on `PageSession` SHALL control optional auto-scroll (paving the way for future audiobook narration). The `seek(Duration)` method MUST throw `UnsupportedError` because page navigation does not have a time-based representation; callers MUST use `goToPage(int)` instead. The `setSpeed` method SHALL adjust auto-scroll speed when auto-scroll is active.

#### Scenario: seek throws UnsupportedError on PageSession

- **WHEN** `pageSession.seek(Duration(seconds: 30))` is called
- **THEN** `UnsupportedError` is thrown with a message that names `goToPage` as the correct entry point

#### Scenario: goToPage updates page position

- **WHEN** `pageSession.goToPage(5)` is called
- **THEN** `pagePositionStream` emits a `PagePosition` with `pageIndex == 5` and `scrollFraction == 0.0` within 200 ms

### Requirement: PageSession persists position to novel_bookmarks on dispose

When a `PageSession` is disposed (e.g., the reader screen is closed), the current `PagePosition` SHALL be upserted into the shared `novel_bookmarks` table provided by `add-online-novel-library` keyed by `(site, externalId, episodeIndex)`. The persisted record MUST store `scrollFraction` (not pixel offset) so that subsequent reads survive font / layout changes.

#### Scenario: Closing the reader saves the current position

- **GIVEN** the user is reading episode 3 at scroll fraction 0.42 of a kakuyomu work
- **WHEN** the user navigates away from the reader screen
- **THEN** an upsert is issued against `novel_bookmarks` with `(site=Site.kakuyomu, externalId, episodeIndex=3, scrollFraction=0.42, updatedAt=<now>)` before the screen is destroyed
