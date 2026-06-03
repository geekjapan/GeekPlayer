## Context

v0.2 includes both local books and manga archives. Manga archives have different constraints from PDF/EPUB: archive inspection must be safe, page ordering is derived from filenames, the reader needs spread and reading-direction controls, and image rendering can be memory-heavy. The existing `PageSession` and home-section registry provide useful foundations.

## Goals / Non-Goals

**Goals:**

- Open local `.zip` and `.cbz` archives containing image pages.
- Render manga pages with single-page and spread layouts.
- Support right-to-left and left-to-right reading direction.
- Support pinch zoom, pan, next/previous navigation, and progress resume.
- Persist manga metadata and bookmarks in dedicated drift tables.
- Protect the app from unsafe or malformed archives.

**Non-Goals:**

- No PDF/EPUB rendering.
- No full library folder scan.
- No remote source integration.
- No AI upscaling or OCR.

## Decisions

### D1. Treat CBZ as ZIP with manga-specific validation

`.cbz` is handled as a ZIP archive with a manga extension. The archive reader inspects entries without extracting to arbitrary filesystem paths. The alternative is extracting archives into app cache first, but that increases cleanup and path traversal risk.

### D2. Add drift schema v5 after the book-reader change

This proposal assumes `add-pdf-epub-reader` lands first and owns schema v4. Manga tables therefore use v5. If apply order changes, the implementation MUST rebase the schema number to latest + 1 and update `docs/CONVENTIONS.md`.

### D3. Keep manga metadata separate from book metadata

Manga archives are local files like books, but they have archive entry manifests, spread preferences, page ordering, and image-specific state. Separate tables avoid making book metadata carry manga-only columns.

### D4. Reuse PageSession without a new MediaSession subtype

Manga progress is page-oriented, so `PageSession` is enough. `PagePosition.index` represents the current manga page or spread anchor, while manga-domain state stores reading direction, spread mode, zoom, and pan.

### D5. Use natural filename ordering with explicit filtering

Archive entries are filtered to supported image extensions and sorted with natural ordering (`2.jpg` before `10.jpg`). Directory entries, hidden metadata, macOS resource forks, and unsupported files are ignored unless no image pages remain.

### D6. Prefer lazy page decode and bounded cache

The viewer decodes only the current page/spread and a small adjacent window. The alternative of decoding the full archive on open is simpler but unsafe for large manga volumes.

## Risks / Trade-offs

- [Risk] ZIP bombs or huge images can exhaust memory -> Mitigation: enforce archive entry count, uncompressed byte, and decoded image dimension limits before rendering.
- [Risk] Filename ordering varies by publisher -> Mitigation: natural ordering is deterministic and can be overridden later by manifest support.
- [Risk] Spread layout is tricky at chapter boundaries -> Mitigation: define clear spread-anchor behavior and test odd/even page counts in both reading directions.
- [Risk] Schema conflicts with book-reader work -> Mitigation: implement after `add-pdf-epub-reader` or rebase schema version to latest + 1 before coding.

## Migration Plan

1. Select archive/image packages after platform compatibility checks.
2. Add manga tables and v5 migration.
3. Implement archive inspection and safety checks.
4. Implement domain repository and `PageSession` adapter.
5. Add manga viewer UI and home-section entry.
6. Add tests, codegen, analyze, and local smoke with a tiny fixture archive.

Rollback before release is a git revert. After a v5 build ships, downgraded app versions must ignore unknown manga tables; existing v1-v4 data must remain intact.

## Open Questions

- Whether future manga folder support should share this metadata model is deferred to a later library-scan change.
