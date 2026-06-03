## 1. Dependency Spike

- [x] 1.1 Evaluate ZIP/CBZ archive-reading packages for macOS, Windows, Android, Linux, and iOS compatibility
- [x] 1.2 Evaluate image decoding/rendering support for jpg, png, webp, and gif on the same platform set
- [x] 1.3 Record chosen package rationale in `design.md` before implementation proceeds
- [x] 1.4 Confirm apply order against `add-pdf-epub-reader`; if book schema v4 is not present, reserve latest schema version + 1 and update this change

## 2. Storage

- [x] 2.1 Add drift tables for manga archive metadata and manga bookmarks
- [x] 2.2 Bump drift schema version from 4 to 5 after `add-pdf-epub-reader` lands
- [x] 2.3 Add v4-to-v5 migration that preserves playback, novel, consent, settings, and book data
- [x] 2.4 Add DAO methods for upserting metadata, updating last-opened time, and CRUD bookmarks
- [x] 2.5 Add migration and DAO tests

## 3. Archive Inspection and Safety

- [x] 3.1 Implement safe ZIP/CBZ entry inspection without arbitrary filesystem extraction
- [x] 3.2 Filter unsupported entries, hidden metadata, directories, and unsafe paths
- [x] 3.3 Implement deterministic natural filename ordering
- [x] 3.4 Enforce entry count, total uncompressed byte, single-entry byte, and decoded dimension limits
- [x] 3.5 Add fixture archives for normal, mixed-entry, traversal, corrupt, empty, and oversized cases

## 4. Domain and Data Layer

- [x] 4.1 Create `MangaArchive`, `MangaPage`, `MangaLocator`, `MangaReadingDirection`, `MangaSpreadMode`, and `MangaBookmark` domain models
- [x] 4.2 Implement repository/use-cases for opening archives, listing recent manga, saving progress, and bookmark operations
- [x] 4.3 Implement a manga `PageSession` adapter backed by archive page progress
- [x] 4.4 Map archive, image, file, unsupported-format, and storage failures to `AppError`

## 5. Presentation

- [x] 5.1 Add `MangaHomeSection` through the home-section registry
- [x] 5.2 Add file-picker entry point for ZIP/CBZ archives
- [x] 5.3 Add Manga Viewer screen with single-page and spread layout modes
- [x] 5.4 Add right-to-left and left-to-right navigation behavior
- [x] 5.5 Add pinch zoom, pan, and configured zoom reset behavior
- [x] 5.6 Add bookmark create/list/jump/delete UI
- [x] 5.7 Localize all new user-visible copy in Japanese and English

## 6. Platform Configuration

- [x] 6.1 Verify macOS sandbox file access entitlements for user-selected archives
- [x] 6.2 Verify Android file picker behavior for ZIP/CBZ access
- [x] 6.3 Verify Windows file-picker behavior with local ZIP/CBZ archives
- [x] 6.4 Document Linux/iOS follow-up constraints if package support is incomplete

## 7. Tests

- [x] 7.1 Add unit tests for archive filtering and natural page ordering
- [x] 7.2 Add safety tests for path traversal, corrupt archive, empty archive, and oversized archive handling
- [x] 7.3 Add repository tests for metadata persistence and recent ordering
- [x] 7.4 Add bookmark persistence tests
- [x] 7.5 Add reader resume tests for page index and spread anchor behavior
- [x] 7.6 Add widget tests for MangaHomeSection and missing-file recovery

## 8. Verification

- [x] 8.1 Run `cd app && dart run build_runner build --delete-conflicting-outputs`
- [x] 8.2 Run `cd app && dart format --output=none --set-exit-if-changed .`
- [x] 8.3 Run `cd app && flutter analyze --fatal-infos`
- [x] 8.4 Run `cd app && flutter test`
- [~] 8.5 Run at least one local macOS smoke test opening a small CBZ archive
  <!-- Automated substitute: fixture generation + ArchiveInspector + page-bytes decode path is covered by test/core/manga/archive_inspector_test.dart (normal.cbz round-trip) and test/features/manga/manga_repository_test.dart (openArchive with writeCbz). True on-device GUI smoke (file-picker → MangaViewerScreen) is a deferred manual release step. -->
- [x] 8.6 Run `openspec validate --all --strict`
- [x] 8.7 Run `git diff --check`
