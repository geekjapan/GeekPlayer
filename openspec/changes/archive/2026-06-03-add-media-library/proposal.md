## Why

v0.2 extends GeekPlayer with a local media library: folder scanning to build a metadata index, watch/play history, favorites/bookmarks, and playlists/play queues. These features turn the app from a single-file launcher into a proper personal library manager for local video and audio content.

## What Changes

- Add folder scanning via `dart:io` that indexes local video and audio files into a `media_index` Drift table.
- Add per-item watch/play history with `watched_at`, duration played, and completion state.
- Add favorites/bookmarks for media items (toggled via a star action).
- Add playlists with ordered items, allowing users to create, rename, reorder, and delete playlists.
- Add a `MediaLibraryHomeSection` at ADR-0004 order 700.
- Persist the schema as Drift v6, with a v5→v6 migration that preserves all earlier data.
- Localize all new user-visible copy in both Japanese and English.

## Non-goals

- No cloud sync, streaming, or network library sources.
- No automatic metadata tagging (ID3 / EXIF) beyond file-level detection; tag parsing is a future enhancement.
- No DRM, license management, or protected content.
- No AI features (transcription, upscaling, chapter detection).
- No playlist export/import formats (M3U, etc.).

## Capabilities

### New Capabilities

- `media-library`: Defines folder scanning, media index, watch history, favorites, and playlist persistence.

### Modified Capabilities

- `app-settings`: Adds a watched folder path list setting and scan-on-launch toggle.
- `error-domain`: Reuses existing `errorFileNotFound` and `errorUnsupportedFormat` for scan failures.

## Impact

- New feature: `app/lib/features/media_library/{data,domain,presentation}/`.
- Storage: Drift schema v6 with four new tables (`media_index`, `watch_history`, `favorites`, `playlists`, `playlist_items`).
- Migration: `app/lib/core/storage/migrations/v5_to_v6.dart`.
- Home integration: new `MediaLibraryHomeSection` registered at order 700.
- Localization: new ARB keys in both `app_ja.arb` and `app_en.arb`.
