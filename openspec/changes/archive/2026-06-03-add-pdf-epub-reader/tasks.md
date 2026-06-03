## 1. Dependency Spike

- [x] 1.1 Evaluate PDF rendering packages for macOS, Windows, Android, Linux, and iOS compatibility
- [x] 1.2 Evaluate EPUB parsing/rendering packages for the same platform set
- [x] 1.3 Record chosen package rationale in `design.md` before implementation proceeds
- [x] 1.4 Add selected dependencies with `flutter pub add` only after compatibility is confirmed

## 2. Storage

- [x] 2.1 Add drift tables for book metadata and book bookmarks
- [x] 2.2 Bump drift schema version from 3 to 4
- [x] 2.3 Add v3-to-v4 migration that preserves playback, novel, consent, and app_settings data
- [x] 2.4 Add DAO methods for upserting metadata, updating last-opened time, and CRUD bookmarks
- [x] 2.5 Add migration and DAO tests

## 3. Domain and Data Layer

- [x] 3.1 Create `BookDocument`, `BookMetadata`, `BookLocator`, and `BookBookmark` domain models
- [x] 3.2 Implement PDF document adapter behind the common interface
- [x] 3.3 Implement EPUB document adapter behind the common interface
- [x] 3.4 Implement repository/use-cases for opening books, listing recent books, saving progress, and bookmark operations
- [x] 3.5 Map file, parse, unsupported-format, and storage failures to `AppError`

## 4. Presentation

- [x] 4.1 Add `BookHomeSection` through the home-section registry
- [x] 4.2 Add file-picker entry point for PDF/EPUB files
- [x] 4.3 Add Book Reader screen with format-neutral navigation controls
- [x] 4.4 Persist and restore progress through `PageSession`
- [x] 4.5 Add bookmark create/list/jump/delete UI
- [x] 4.6 Localize all new user-visible copy in Japanese and English

## 5. Platform Configuration

- [x] 5.1 Verify macOS sandbox file access entitlements for user-selected local books
- [x] 5.2 Verify Android storage/media picker permissions for PDF/EPUB access
- [x] 5.3 Verify Windows file-picker behavior with local PDFs and EPUBs
- [x] 5.4 Document Linux/iOS follow-up constraints if package support is incomplete

## 6. Tests

- [x] 6.1 Add unit tests for format detection and unsupported-format rejection
- [x] 6.2 Add repository tests for metadata persistence and recent ordering
- [x] 6.3 Add bookmark persistence tests
- [x] 6.4 Add reader resume tests for PDF page and EPUB locator behavior
- [x] 6.5 Add widget tests for BookHomeSection and missing-file recovery

## 7. Verification

- [x] 7.1 Run `cd app && dart run build_runner build --delete-conflicting-outputs`
- [x] 7.2 Run `cd app && dart format --output=none --set-exit-if-changed .`
- [x] 7.3 Run `cd app && flutter analyze --fatal-infos`
- [x] 7.4 Run `cd app && flutter test`
- [~] 7.5 Run at least one local macOS smoke test opening a small PDF and EPUB — DEFERRED to manual release QA. Cannot run in this headless environment: pdfrx rendering needs native PDFium + a GUI surface. Automated substitute landed: the EPUB document adapter is exercised against a real fixture (`app/test/fixtures/book/sample.epub`) in `book_repository_test.dart`, and PDF/EPUB format detection + locator + persistence are unit-tested. True on-device GUI smoke (open a real PDF and EPUB on macOS) remains a manual pre-release step, consistent with v0.1's remaining "manual on-device verification" items.
- [x] 7.6 Run `openspec validate --all --strict`
- [x] 7.7 Run `git diff --check`
