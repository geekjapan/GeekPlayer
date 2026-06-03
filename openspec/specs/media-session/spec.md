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

### Requirement: AudioSession variant of MediaSession

The system SHALL provide an `AudioSession` concrete implementation of the `MediaSession` sealed type at `app/lib/core/media/audio_session.dart`, backed by `just_audio`'s `AudioPlayer` and integrated with `audio_service`. `AudioSession` MUST satisfy all base `MediaSession` requirements (position / play state / duration streams, play / pause / seek / setSpeed / dispose).

#### Scenario: AudioSession is a valid MediaSession variant

- **WHEN** a switch expression over `MediaSession` lists `case VideoSession()` and `case AudioSession()`
- **THEN** the analyzer accepts the switch as exhaustive

#### Scenario: AudioSession emits play state changes

- **WHEN** `AudioSession.play()` is called on an idle session
- **THEN** `playStateStream` emits `loading` followed by `playing` within 1 second

### Requirement: Background playback continues when app is backgrounded

The system SHALL keep audio playback running when the app goes to the background. On Android, the playback MUST be promoted to a foreground service via `audio_service` so the OS does not kill it. On macOS, the app MUST declare audio as a background-capable activity.

#### Scenario: Backgrounding does not interrupt playback

- **GIVEN** an `AudioSession` is in `playing` state
- **WHEN** the user backgrounds the app for 60 seconds
- **THEN** audio continues playing for the entire 60 seconds and `playStateStream` remains `playing`

### Requirement: OS MediaSession integration

The system SHALL expose the currently-playing audio to the OS's media session API so that lock screen / notification center controls, headphone buttons, and Bluetooth remotes can drive playback. The OS metadata MUST include title, artist, album, and artwork when available.

#### Scenario: Headphone play / pause button toggles state

- **GIVEN** an `AudioSession` is in `playing` state
- **WHEN** the user presses the play / pause button on connected headphones
- **THEN** playback pauses and `playStateStream` emits `paused`

#### Scenario: Lock screen displays current track metadata

- **GIVEN** an `AudioSession` is playing a file whose tags contain title "Hoge" and artist "Fuga"
- **WHEN** the device lock screen is shown
- **THEN** "Hoge" and "Fuga" appear on the lock screen along with the embedded artwork if present

### Requirement: Audio focus handling

The system SHALL release audio focus when interrupted (incoming call, navigation prompt, another media app) and resume on transient interruptions. The behaviour MUST follow the platform conventions provided by `audio_service`.

#### Scenario: Incoming call pauses playback

- **GIVEN** an `AudioSession` is in `playing` state
- **WHEN** the device receives a phone call
- **THEN** playback pauses; after the call ends, playback resumes automatically (unless the user paused manually during the call)

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

