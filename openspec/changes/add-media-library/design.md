## Context

v0.2 adds a local media library. The app already has `PlaybackPositions` and `RecentItems` for per-URI progress, but there is no concept of a scanned folder index, favorites, or ordered playlists. This change layers those features onto the existing Drift infrastructure without breaking any existing tables.

## Goals / Non-Goals

**Goals:**

- Scan one or more user-nominated folders (via `dart:io`) and index discovered video/audio files.
- Persist per-item watch/play history (last played, position, completion flag).
- Allow users to toggle a favorite/bookmark flag on any indexed item.
- Allow users to create playlists, add/remove/reorder items, and play them sequentially.
- Integrate with the home-section registry at order 700.
- Bump Drift schema to v6 with a tested migration.

**Non-Goals:**

- No ID3/EXIF tag parsing.
- No cloud sync.
- No M3U/PLS playlist import-export.
- No network sources.

## Decisions

### D1. Four new Drift tables in v6

- `media_index` — one row per discovered file: URI, path, kind (`video`/`audio`), title (filename stem), file size, last modified, scan time.
- `watch_history` — one row per URI: last played timestamp, position_ms, duration_ms, and a boolean `completed` flag. URI is the primary key (upsert semantics like `playback_positions`).
- `favorites` — one row per URI: just a `favoritedAt` timestamp. URI is primary key.
- `playlists` — one row per playlist: auto-increment id, name, created_at, updated_at.
- `playlist_items` — join table: playlist_id, media_uri, position (sort order). Composite PK `(playlist_id, media_uri)`.

Five tables total, not four. `watch_history` replaces the need to overload `playback_positions` with history semantics.

### D2. Folder scanning is synchronous dart:io, no native plugin

`dart:io Directory.list(recursive: true)` is sufficient for the MVP. Supported extensions: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.mp3`, `.flac`, `.aac`, `.wav`, `.ogg`, `.m4a`, `.opus`. Scanning runs in an isolate spawned by the repository to keep the UI thread free.

### D3. Watch history and playback_positions remain separate

`watch_history` tracks library semantics (watched, completed, last position). `playback_positions` remains the lightweight resume store used by the player. The library reads `playback_positions` on demand to pre-populate `watch_history.position_ms` but does not merge the tables.

### D4. Favorites stored as a presence table

A row in `favorites` means "favorited". Deletion means "unfavorited". This avoids a boolean column and makes count queries trivial.

### D5. Playlist item ordering via integer position column

`playlist_items.position` is an integer that the UI reorders by updating all affected rows. This is simpler than a linked-list approach and acceptable for typical playlist sizes (<1000 items).

### D6. HomeSection order 700

Per ADR-0004, available slots after v0.2 book (500) and manga (600) are 700+. The media library section registers at 700.

### D7. No new pub dependencies

Folder scanning uses `dart:io`. Media detection uses extension matching. No new packages are required.

## Risks / Trade-offs

- [Risk] Large folder scans (10k+ files) may block briefly even in an isolate -> Mitigation: batch inserts and emit progress events; MVP tolerance is acceptable.
- [Risk] Files deleted between scan and playback -> Mitigation: reuse existing `errorFileNotFound` error path; no special migration needed.
- [Risk] Database migration risk -> Mitigation: add v5→v6 migration tests preserving all v1–v5 data.

## Migration Plan

1. Add Drift table files for the five new tables.
2. Bump `schemaVersion` to 6 and add `v5_to_v6.dart` migration.
3. Add migration and DAO tests.
4. Implement domain models and repository.
5. Add `MediaLibraryHomeSection` UI and register in `home_section_registry.dart`.
6. Add ARB localizations and run `flutter gen-l10n`.
7. Run codegen, analyze, test, validate.

Rollback: revert code before first v6 release. Once v6 ships, downgrade must ignore new tables.
