## ADDED Requirements

### Requirement: PageSession variant in the sealed hierarchy

The system SHALL extend the sealed `MediaSession` hierarchy (defined by `add-local-video-playback`) with a `PageSession` variant at `app/lib/core/novel/page_session.dart`. `PageSession` MUST be `sealed` itself so future book / manga variants can extend it without leaving the `MediaSession` exhaustivity guarantee. Adding the `PageSession` variant MUST require every existing pattern-match site over `MediaSession` to add a corresponding case.

#### Scenario: Exhaustive switching includes PageSession

- **WHEN** a `switch` statement over a `MediaSession` value is compiled after this change
- **THEN** the analyzer reports `non_exhaustive_switch_expression` unless the switch includes a `PageSession` case in addition to the existing `VideoSession` (and future `AudioSession`) cases

#### Scenario: PageSession is itself sealed

- **WHEN** a developer attempts to create a non-library subclass of `PageSession` outside of `app/lib/core/novel/` or `app/lib/features/novel/`
- **THEN** the analyzer reports a sealed-class violation

### Requirement: PagePosition value object

The system SHALL define `PagePosition` as an immutable value object carrying `pageIndex (int, 1-based)` and `scrollFraction (double, 0.0..1.0 inclusive)`. Both fields MUST be validated at construction; out-of-range values MUST throw `ArgumentError`.

#### Scenario: Valid PagePosition is constructed

- **WHEN** `PagePosition(pageIndex: 3, scrollFraction: 0.5)` is constructed
- **THEN** no error is thrown and the value compares equal to another `PagePosition(pageIndex: 3, scrollFraction: 0.5)`

#### Scenario: pageIndex below 1 is rejected

- **WHEN** `PagePosition(pageIndex: 0, scrollFraction: 0.0)` is constructed
- **THEN** `ArgumentError` is thrown

#### Scenario: scrollFraction outside [0,1] is rejected

- **WHEN** `PagePosition(pageIndex: 1, scrollFraction: 1.5)` is constructed
- **THEN** `ArgumentError` is thrown

### Requirement: PageSession operations

`PageSession` SHALL expose `pagePositionStream (Stream<PagePosition>)`, `totalPages (int)`, `goToPage(int index)`, and `updateScrollFraction(double fraction)`. The `seek(Duration)` operation inherited from `MediaSession` MUST throw `UnsupportedError` on `PageSession` to force callers to use `goToPage` explicitly. The `play()` / `pause()` operations MAY be implemented as auto-scroll start / stop or as no-ops.

#### Scenario: pagePositionStream emits on navigation

- **GIVEN** a `PageSession` is loaded with a Work of 10 episodes
- **WHEN** `goToPage(3)` is called
- **THEN** `pagePositionStream` emits a `PagePosition` with `pageIndex == 3` within 100ms

#### Scenario: seek throws UnsupportedError

- **WHEN** `session.seek(Duration(seconds: 10))` is called on a `PageSession`
- **THEN** `UnsupportedError` is thrown synchronously with a message that points to `goToPage`

#### Scenario: updateScrollFraction updates within the current page

- **GIVEN** the current `PagePosition` is `(pageIndex: 4, scrollFraction: 0.0)`
- **WHEN** `updateScrollFraction(0.7)` is called
- **THEN** the next emitted `PagePosition` is `(pageIndex: 4, scrollFraction: 0.7)`

### Requirement: PageSession lifecycle through Riverpod

The system SHALL manage `PageSession` lifecycle via an `AutoDispose` Riverpod provider, mirroring the `VideoSession` pattern. When the reader screen is disposed, the corresponding `PageSession.dispose()` MUST be invoked, the bookmark for the active Work MUST be written to `novel_bookmarks`, and all streams MUST complete.

#### Scenario: Leaving the reader writes the bookmark

- **GIVEN** a `PageSession` is active with `PagePosition(pageIndex: 5, scrollFraction: 0.3)` for a Library Work
- **WHEN** the reader screen is popped
- **THEN** `dispose()` is called, the `novel_bookmarks` upsert is executed before the provider tears down, and `pagePositionStream` completes
