# local-video-playback Specification

## Purpose
TBD - created by archiving change add-local-video-playback. Update Purpose after archive.
## Requirements
### Requirement: Open a local video file via the OS file picker

The system SHALL allow the user to choose a local video file via the platform native file picker from the home screen, and SHALL navigate to the player screen with that file loaded. Supported container formats MUST include at minimum mp4, mkv, mov, and webm. Files larger than 16 GiB MUST be supported on 64-bit platforms.

#### Scenario: User picks an mp4 file from the home screen

- **WHEN** the user taps the "動画を開く" button on the home screen and selects an mp4 file in the OS picker
- **THEN** the player screen opens, the video begins playing automatically, and the file's URI is recorded in `recent_items` with `kind = 'video'`

#### Scenario: User cancels the file picker

- **WHEN** the user opens the file picker and cancels without selecting a file
- **THEN** the home screen remains visible, no `recent_items` entry is created, and no error is shown

#### Scenario: User picks an unsupported file

- **WHEN** the user selects a file whose container is not supported by media_kit
- **THEN** the player screen displays an error message ("このファイルは再生できません") with a back button and does not crash

### Requirement: Playback controls

The player screen SHALL provide play / pause, seek, playback-speed, and subtitle toggle controls. Controls MUST appear when the user taps the video surface and SHALL auto-hide after 3 seconds of inactivity. The playback-speed selector MUST offer the presets 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, and 2.0.

#### Scenario: Play / pause toggles state

- **WHEN** the user taps the play / pause button while playing
- **THEN** playback pauses and the underlying `MediaSession.playStateStream` emits `paused`; tapping again resumes and emits `playing`

#### Scenario: Seek bar updates position

- **WHEN** the user drags the seek bar to a target position
- **THEN** the underlying `MediaSession.seek(target)` is called and `positionStream` reflects the new position within 500ms

#### Scenario: Speed selection persists for the session

- **WHEN** the user selects 1.5x on the speed selector
- **THEN** playback speed becomes 1.5x for the remainder of the current session, and is reset to 1.0x the next time the same file is opened

#### Scenario: Subtitle toggle uses the embedded track

- **GIVEN** the loaded video has at least one embedded subtitle track
- **WHEN** the user taps the subtitle toggle
- **THEN** the first embedded subtitle track is shown; tapping again hides subtitles

### Requirement: Resume from last position

The system SHALL persist the playback position for each opened video file to the `playback_positions` table, keyed by the file's normalized `file://` URI. When the same file is opened again, the player SHALL resume from the saved position, except when the previous position is within 5 seconds of the end of the media (in which case playback starts from the beginning).

#### Scenario: Resume from saved position

- **GIVEN** a video file has a previously saved `playback_positions` entry at 10 minutes 30 seconds
- **WHEN** the user opens the same file again
- **THEN** playback starts at 10 minutes 30 seconds within 1 second of the player screen appearing

#### Scenario: Watched-to-end restarts from beginning

- **GIVEN** a video file's saved position is within 5 seconds of its total duration
- **WHEN** the user opens the same file again
- **THEN** playback starts from position 0

#### Scenario: Position is saved on exit

- **WHEN** the user leaves the player screen (back button or close)
- **THEN** the current playback position is written to `playback_positions` before the screen is destroyed

### Requirement: Recent items list

The home screen SHALL display the most recently opened video files in reverse chronological order, capped at 50 entries. Each entry MUST display the file name and the opened-at timestamp, and tapping an entry MUST open the file in the player screen with resume behavior applied.

#### Scenario: Empty state

- **WHEN** the home screen is displayed and `recent_items` is empty
- **THEN** a placeholder message ("最近開いた動画はまだありません") is shown instead of an empty list

#### Scenario: Most recent file appears first

- **WHEN** the user opens video A, then video B, then video A again
- **THEN** the "最近開いた" list shows A at the top and B as the second entry

#### Scenario: Cap at 50 entries

- **WHEN** the user has opened more than 50 distinct video files
- **THEN** only the 50 most recently opened entries are shown, and older entries are pruned from `recent_items`

#### Scenario: Stale entry is removed when file is missing

- **WHEN** the user taps a recent entry whose underlying file no longer exists at the recorded path
- **THEN** an error message is shown and the entry is removed from `recent_items`

### Requirement: Platform parity for v0.1 targets

The video playback feature SHALL work on macOS, Windows, and Android. On Android, the app MUST request `READ_MEDIA_VIDEO` permission (API 33+) or `READ_EXTERNAL_STORAGE` (API < 33) before opening the file picker. On macOS, the app MUST declare the `com.apple.security.files.user-selected.read-only` entitlement.

#### Scenario: Android permission flow

- **GIVEN** the app is running on Android 13+ and the user has never granted media permissions
- **WHEN** the user taps "動画を開く"
- **THEN** the system permission dialog requests `READ_MEDIA_VIDEO`, and on grant proceeds to the file picker; on denial shows an explanatory message with a link to settings

#### Scenario: macOS sandbox grants read access

- **WHEN** the user picks a video file from outside the app's sandbox container on macOS
- **THEN** the file can be opened and played without additional permission prompts

