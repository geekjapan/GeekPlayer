## ADDED Requirements

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
