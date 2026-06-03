## Why

v0.2 expands GeekPlayer into local reading surfaces, and manga ZIP/CBZ is the second reader pillar alongside PDF/EPUB. This change adds a focused manga viewer so image-archive reading, spread layout, reading direction, zoom, and progress persistence are designed explicitly instead of being forced through the book reader model.

## What Changes

- Add a local manga viewer for `.zip` and `.cbz` archives containing image pages.
- Support right-to-left and left-to-right reading direction, single-page and two-page spread modes, pinch zoom, pan, and page navigation.
- Persist manga metadata, recent items, reading progress, and bookmarks separately from books and online novels.
- Add a `MangaHomeSection` through the existing home-section registry order reserved for manga.
- Add archive-safety checks for path traversal, unsupported entries, very large archives, corrupt files, and deterministic page ordering.

## Non-goals

- No DRM support.
- No PDF/EPUB support; that belongs to `add-pdf-epub-reader`.
- No folder scan or full library import beyond user-selected archives.
- No image upscaling, OCR, translation, or AI enhancement.
- No remote manga sources.

## Capabilities

### New Capabilities

- `local-manga-zip-viewer`: Defines ZIP/CBZ opening, image-page rendering, reading direction, spread layout, zoom/pan, navigation, and resume behavior.
- `manga-library`: Defines local manga archive metadata, recent-manga behavior, bookmarks, and home-section integration.
- `manga-archive-safety`: Defines safe archive inspection, entry filtering, page ordering, size limits, and corrupt archive handling.

### Modified Capabilities

- `media-session`: Defines how manga reading uses the existing `PageSession` abstraction without adding a new `MediaSession` subtype.
- `app-settings`: Adds manga reader defaults such as reading direction, spread mode, and zoom reset behavior.
- `error-domain`: Adds or reuses errors for corrupt archives, unsupported image formats, missing files, archive size limits, and storage failures.

## Impact

- New feature: `app/lib/features/manga/{data,domain,presentation}/`.
- Existing placeholder: `app/lib/features/manga/.gitkeep:1`.
- Shared page model: `app/lib/core/media/page_session.dart:1`, `app/lib/core/media/page_position.dart:1`, `app/lib/core/media/media_session.dart:1`.
- Home integration: `app/lib/features/library/home_section.dart:13`.
- Storage: `app/lib/core/storage/database.dart:1` and new drift tables/migrations for manga archive metadata and bookmarks.
- Docs: `docs/roadmap.md:37`, `docs/CONVENTIONS.md:45`.
