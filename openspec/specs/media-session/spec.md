# media-session Specification

## Purpose
TBD - created by archiving change add-local-video-playback. Update Purpose after archive.
## Requirements
### Requirement: MediaSession abstraction

The system SHALL provide a `MediaSession` interface at `app/lib/core/media/media_session.dart` that abstracts media playback / viewing state. The interface MUST expose position, play state, duration, and playback speed via observable streams, and MUST support play, pause, seek, set-speed, and dispose operations.

#### Scenario: A concrete session emits state changes through streams

- **WHEN** a `MediaSession` implementation is constructed and an observer subscribes to `positionStream`, `playStateStream`, and `durationStream`
- **THEN** the streams emit at least one initial value within 500ms and continue to emit values whenever the underlying engine reports a change

#### Scenario: Disposing a session releases native resources

- **WHEN** `dispose()` is called on a `MediaSession`
- **THEN** all streams complete, subsequent operations throw `StateError`, and the underlying engine resources are released within 1 second

### Requirement: MediaPosition / MediaSpeed / MediaPlayState value objects

The system SHALL define `MediaPosition`, `MediaSpeed`, and `MediaPlayState` as immutable value objects in `app/lib/core/media/models.dart`. `MediaPosition` MUST carry the current position as `Duration` and the buffered range. `MediaSpeed` MUST carry the speed as a `double` and validate that it is greater than 0. `MediaPlayState` MUST be a sealed enum-like type covering at minimum `idle`, `loading`, `playing`, `paused`, and `ended`.

#### Scenario: MediaSpeed rejects non-positive values

- **WHEN** `MediaSpeed(0)` or `MediaSpeed(-1.0)` is constructed
- **THEN** an `ArgumentError` is thrown

#### Scenario: MediaPlayState reaches `ended` at the end of media

- **WHEN** playback reaches the end of the media
- **THEN** the most recent value emitted on `playStateStream` is `MediaPlayState.ended`

### Requirement: Sealed type hierarchy for session variants

The system SHALL declare `MediaSession` as a `sealed` class so that exhaustive pattern matching is possible on the variants (`VideoSession`, and future `AudioSession` / `PageSession`). Adding a new variant MUST require adding a corresponding case at every pattern-match site.

#### Scenario: Exhaustive switching over session variants compiles

- **WHEN** an arbitrary `MediaSession` value is switched on
- **THEN** the analyzer requires every concrete variant to be handled, otherwise reports `non_exhaustive_switch_expression`

