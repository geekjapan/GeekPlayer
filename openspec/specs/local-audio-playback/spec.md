# local-audio-playback Specification

## Purpose
TBD - created by archiving change add-local-audio-playback. Update Purpose after archive.
## Requirements
### Requirement: Open a local audio file or folder via the OS picker

The system SHALL allow the user to choose a local audio file or a folder via the platform native picker from the home screen, and SHALL navigate to the player screen with that file loaded and playback started. Supported container formats MUST include at minimum mp3, flac, m4a, aac, ogg, opus, and wav. When the user picks a folder, the system MUST enumerate the audio files in that folder (non-recursive) and build the in-memory queue in file-name ascending order.

#### Scenario: User picks an mp3 file from the home screen

- **WHEN** the user taps the "音楽を開く" button on the home screen and selects an mp3 file in the OS picker
- **THEN** the player screen opens, playback begins automatically, and the file's URI is recorded in `recent_items` with `kind = 'audio'`

#### Scenario: User picks a folder containing multiple audio files

- **WHEN** the user picks a folder that contains 5 supported audio files and 2 unsupported files
- **THEN** the 5 supported files SHALL form the queue in file-name ascending order, the first track begins playing, and the folder URI is recorded in `recent_items` with `kind = 'audio'`

#### Scenario: User cancels the picker

- **WHEN** the user opens the picker and cancels without selecting a file or folder
- **THEN** the home screen remains visible, no `recent_items` entry is created, and no error is shown

#### Scenario: User picks an unsupported file

- **WHEN** the user selects a file whose extension is not in the supported list
- **THEN** the player screen displays an error message ("このファイルは再生できません") with a back button and does not crash

### Requirement: Audio playback controls

The player screen SHALL provide play / pause, seek, playback-speed, shuffle, and repeat controls. The playback-speed selector MUST offer the presets 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, and 2.0. The repeat control MUST cycle through three modes (`none`, `one`, `all`) with `none` as the default.

#### Scenario: Play / pause toggles state

- **WHEN** the user taps the play / pause button while playing
- **THEN** playback pauses and `AudioSession.playStateStream` emits `paused`; tapping again resumes and emits `playing`

#### Scenario: Seek bar updates position

- **WHEN** the user drags the seek bar to a target position
- **THEN** `AudioSession.seek(target)` is called and `positionStream` reflects the new position within 500ms

#### Scenario: Speed selection persists for the session

- **WHEN** the user selects 1.5x on the speed selector
- **THEN** playback speed becomes 1.5x for the remainder of the current session, and is reset to 1.0x the next time a track is opened from the home screen

#### Scenario: Repeat mode cycles

- **WHEN** the user taps the repeat button three times starting from `none`
- **THEN** the mode transitions `none` → `all` → `one` → `none`, and after the last tap a single-track repeat behaviour is applied

### Requirement: Queue navigation

When a queue exists (either folder-derived or single-file), the player screen SHALL provide previous / next controls. The system SHALL advance to the next track automatically when the current track ends, except when repeat mode is `one`. When repeat mode is `all` and the queue reaches the last track, advancement MUST wrap around to the first track. When repeat mode is `none` and the last track ends, the system MUST stop playback and emit `MediaPlayState.ended`.

#### Scenario: Next button advances to the next queue entry

- **GIVEN** a queue of three tracks (A, B, C) with A currently playing
- **WHEN** the user taps the next button
- **THEN** track B begins playing and `positionStream` restarts from 0

#### Scenario: Previous button at queue head restarts current track

- **GIVEN** the first track in the queue is playing at 30 seconds
- **WHEN** the user taps the previous button
- **THEN** the same track is seeked to position 0 and continues playing

#### Scenario: Shuffle preserves the currently playing track

- **GIVEN** a queue of five tracks with the third track playing
- **WHEN** the user enables shuffle
- **THEN** the third track remains the current track, and the other four tracks are reordered randomly for upcoming playback

### Requirement: Metadata display

The system SHALL display the track's title, artist, album, and embedded artwork on the player screen and the mini player. Tags MUST be read via `audio_metadata_reader` and loaded asynchronously when a track is made current. When a tag is missing, the system MUST fall back to the file name without extension for the title, "不明なアーティスト" for the artist, and an empty string for the album. When artwork is missing or fails to load, the system MUST show a default music-note placeholder icon.

#### Scenario: Tagged track shows full metadata

- **GIVEN** an mp3 file whose tags contain title "Hoge", artist "Fuga", album "Piyo", and embedded artwork
- **WHEN** the track becomes current on the player screen
- **THEN** "Hoge", "Fuga", "Piyo", and the artwork are displayed within 2 seconds of the track loading

#### Scenario: Missing tags fall back to file name

- **GIVEN** a wav file with no tags at path `/music/sample.wav`
- **WHEN** the track becomes current
- **THEN** the title shows "sample", the artist shows "不明なアーティスト", and the artwork shows the default placeholder icon

### Requirement: Resume from last position

The system SHALL persist the playback position for each opened audio track to the shared `playback_positions` table, keyed by the track's normalized `file://` URI. When the same track is opened again, the player SHALL resume from the saved position, except when the previous position is within 5 seconds of the end of the track (in which case playback starts from the beginning). The position MUST be written before the `AudioSession` is disposed for that track.

#### Scenario: Resume from saved position

- **GIVEN** an audio track has a previously saved `playback_positions` entry at 2 minutes 15 seconds
- **WHEN** the user opens the same track again
- **THEN** playback starts at 2 minutes 15 seconds within 1 second of the player screen appearing

#### Scenario: Listened-to-end restarts from beginning

- **GIVEN** a track's saved position is within 5 seconds of its total duration
- **WHEN** the user opens the same track again
- **THEN** playback starts from position 0

#### Scenario: Position is saved when switching tracks

- **WHEN** the user taps the next button while playing track A at 1 minute 10 seconds
- **THEN** position 1m10s is written to `playback_positions` for track A before track B starts loading

### Requirement: Recent audio items list

The home screen SHALL display the most recently opened audio entries in reverse chronological order, capped at 50 entries that share the global `recent_items` table with `kind = 'audio'`. Each entry MUST display the file or folder name and the opened-at timestamp, and tapping an entry MUST open the entry in the player screen with resume behavior applied. The 50-entry cap MUST be enforced per `kind` so that audio entries do not displace video entries and vice versa.

#### Scenario: Empty state

- **WHEN** the home screen is displayed and no `recent_items` row with `kind = 'audio'` exists
- **THEN** the audio section shows the placeholder message "最近開いた音楽はまだありません" instead of an empty list

#### Scenario: Most recent entry appears first

- **WHEN** the user opens track A, then track B, then track A again
- **THEN** the audio "最近開いた" list shows A at the top and B as the second entry

#### Scenario: Cap at 50 audio entries

- **WHEN** the user has opened more than 50 distinct audio entries
- **THEN** only the 50 most recently opened entries with `kind = 'audio'` are shown, and older audio entries are pruned from `recent_items` while `kind = 'video'` entries remain untouched

#### Scenario: Stale entry is removed when source is missing

- **WHEN** the user taps a recent entry whose underlying file or folder no longer exists
- **THEN** an error message is shown and the entry is removed from `recent_items`

### Requirement: Mini player on the home screen

The system SHALL display a `MiniPlayer` widget pinned to the bottom of the home screen whenever an `AudioSession` exists and its `playStateStream` is not `idle`. The mini player MUST show the current track title, artist, artwork, and a play / pause button, and tapping the mini player surface MUST navigate to the full `PlayerScreen`. When no audio is loaded or the session is idle, the mini player MUST be hidden so it does not occupy layout space.

#### Scenario: Mini player appears when playback starts

- **GIVEN** the home screen is displayed with no active audio session
- **WHEN** the user opens an audio track and playback starts
- **THEN** the mini player appears pinned to the bottom of the home screen showing the current track's title and artwork

#### Scenario: Tapping the mini player opens the player screen

- **WHEN** the user taps anywhere on the mini player surface other than the play / pause button
- **THEN** the full `PlayerScreen` is pushed onto the navigator with the current `AudioSession`

#### Scenario: Mini player hides when session ends

- **GIVEN** the mini player is visible with a paused session
- **WHEN** the session reaches `MediaPlayState.ended` and is disposed
- **THEN** the mini player is removed from the layout and the home screen reclaims that space

### Requirement: Platform parity for v0.1 targets

The audio playback feature SHALL work on macOS, Windows, and Android. On Android 13+, the app MUST request the `POST_NOTIFICATIONS` runtime permission before the first foreground-service notification is posted by `audio_service`. On macOS, the app MUST enable the audio background entitlement and declare `audio` in `Info.plist`'s `LSBackgroundModes` so playback continues when the app is not frontmost.

#### Scenario: Android notification permission flow

- **GIVEN** the app is running on Android 13+ and the user has never granted `POST_NOTIFICATIONS`
- **WHEN** the user starts playback for the first time
- **THEN** the system permission dialog requests `POST_NOTIFICATIONS`; on grant the `audio_service` foreground notification appears, on denial playback still proceeds but no notification is shown and an in-app banner explains the limitation

#### Scenario: macOS background playback declaration

- **WHEN** the app's Info.plist is inspected on a release build for macOS
- **THEN** `LSBackgroundModes` contains an `audio` entry and the audio background entitlement is enabled in the app's entitlements file

#### Scenario: Windows playback works without extra permissions

- **WHEN** the user opens an audio file on Windows
- **THEN** playback starts without any runtime permission prompt and continues when the window loses focus

