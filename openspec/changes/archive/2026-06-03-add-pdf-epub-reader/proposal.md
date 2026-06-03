## Why

v0.2 expands GeekPlayer from media playback and online novels into local books. PDF/EPUB support should be added before broader library scanning so the reader model, progress persistence, and home-section integration are shaped around real book content.

## What Changes

- Add a local book reader for PDF and EPUB files.
- Reuse the existing `PageSession` abstraction for page/scroll progress, resume, and future narration hooks.
- Add book-specific persistence for recent items, bookmarks, reading progress, and imported local file metadata.
- Add a `BookHomeSection` and reader entry points consistent with the home-section registry.
- Add platform file-picker permissions and format-validation errors for PDF/EPUB.

## Non-goals

- No DRM-protected EPUB/PDF support.
- No cloud sync, annotations export, or full library folder scan.
- No comic archive/CBZ support; that belongs to a separate manga viewer change.
- No AI upscaling or OCR.

## Capabilities

### New Capabilities

- `local-book-reader`: Defines PDF/EPUB opening, rendering, navigation, progress persistence, and error handling.
- `book-library`: Defines local book metadata, recent-book behavior, bookmarks, and home-section integration.

### Modified Capabilities

- `media-session`: Extends `PageSession` usage from online novels into local books and defines book-specific progress semantics.
- `app-settings`: Adds book reader display defaults such as writing direction applicability, font/spacing behavior for EPUB, and PDF zoom defaults.
- `error-domain`: Adds or reuses errors for unsupported book formats, missing files, parse failures, and storage failures.

## Impact

- New feature: `app/lib/features/book/{data,domain,presentation}/`.
- Shared media/page model: `app/lib/core/media/page_session.dart`, `app/lib/core/media/page_position.dart`, `app/lib/core/media/media_session.dart`.
- Storage: `app/lib/core/storage/database.dart` and new drift tables/migrations for book metadata and bookmarks.
- Home integration: `app/lib/features/library/home_section.dart`, `app/lib/features/library/home_section_registry.dart`.
- Docs: `docs/roadmap.md:36`, `docs/adr/0002-hybrid-media-engine.md:20`, `docs/CONVENTIONS.md:45`.
