## Context

v0.2 adds local books. The app already has `PageSession` and novel bookmark concepts, but local PDF/EPUB content has different rendering, metadata, progress, and persistence needs. This change introduces books without taking on manga archives or broad folder scanning.

## Goals / Non-Goals

**Goals:**

- Open local PDF and EPUB files from the user file picker.
- Render readable book content with page/scroll navigation and resume.
- Persist book metadata, recent-book entries, and bookmarks.
- Integrate the book feature into the home-section registry.
- Reuse `PageSession` where it matches local book progress semantics.

**Non-Goals:**

- No DRM support.
- No CBZ/ZIP manga support.
- No full folder scanning or cloud library.
- No annotation export, OCR, or AI upscaling.

## Decisions

### D1. Split PDF and EPUB rendering behind a common BookDocument interface

`BookDocument` exposes metadata, chapter/page navigation, and current `PagePosition`. PDF and EPUB adapters can use different rendering packages internally while the UI works through one reader controller.

### D2. Add drift schema v4 for books

Create book tables in v4 rather than overloading novel tables. Books are local files, while novels are site-backed works with external IDs. Keeping tables separate avoids leaking site concepts into local-file behavior.

### D3. Store stable file identity plus display metadata

Persist URI, normalized path, file size, last modified timestamp, title, author, format, and last opened time. If the file disappears, keep metadata and surface a recoverable `FileNotFoundError`.

### D4. Use PageSession for current reading state

Local books use `PageSession` for resume and progress. EPUB stores logical location/chapter plus scroll fraction; PDF stores page index plus zoom/offset where available. The shared API remains abstract enough for future manga support.

### D5. Keep package selection implementation-time but test-gated

The task list includes a package evaluation step for PDF and EPUB libraries. Candidate dependencies must support macOS, Windows, Android, and eventually Linux/iOS. Selection must be recorded in the final implementation notes.

## Risks / Trade-offs

- [Risk] EPUB rendering packages vary in platform support -> Mitigation: spike package compatibility before wiring persistence.
- [Risk] PDF page rendering can be memory-heavy -> Mitigation: require lazy page rendering and no whole-document bitmap cache.
- [Risk] Book progress semantics differ by format -> Mitigation: persist format-specific locator fields behind a common domain object.
- [Risk] Database migration risk -> Mitigation: add v3->v4 migration tests preserving all existing v1-v3 data.

## Migration Plan

1. Add dependencies after compatibility spike.
2. Add book tables and v4 migration.
3. Implement domain interfaces and adapters.
4. Add reader UI and home-section entry.
5. Add tests, codegen, analyze, and targeted manual smoke.

Rollback requires reverting code and migration before release. Once a v4 build ships, downgrade behavior must preserve existing v1-v3 tables and ignore unknown book tables.

## Package Selection (task 1.3)

### PDF: `pdfrx ^1.0.0`

- **License**: Apache-2.0 (permissive; no GPL/LGPL).
- **Platforms**: macOS, Windows, Android, iOS, Linux — native PDFium binding via `pdfium_binaries`.
- **Rendering**: `PdfPageView` renders pages lazily; no whole-document bitmap cache; zoom/scroll via `InteractiveViewer`.
- **Rejected alternatives**: `syncfusion_flutter_pdfviewer` (non-permissive commercial license), `flutter_pdf_viewer` (abandoned).

### EPUB: custom parser using `archive ^4.x` + `xml ^6.x` + `flutter_html ^3.0.0`

- **License**: BSD-3/MIT/Apache-2.0 for all three deps (all permissive).
- **Platforms**: pure-Dart ZIP + XML parsing; `flutter_html` renders chapter HTML. Works on all Flutter platforms.
- **Rendering**: Custom `EpubDocument` parses OPF/NCX/HTML from the ZIP container; each chapter is rendered with `flutter_html` inside a `SingleChildScrollView`; chapter progress stored as scroll fraction via `ScrollController`.
- **Rejected alternatives**: `epub_view` (requires `epubx` which conflicts with `image ^4.x` needed by `media_kit`); `epub_decoder` (requires `archive ^3.x` conflicting with `pdfrx_engine ^4.x`); `flutter_epub_reader` (InAppWebView — too heavy).

## Open Questions

*Resolved.* Package selection recorded above (task 1.3 complete).
