## ADDED Requirements

### Requirement: macOS/Windows media/viewer operation-flow audit is documented with concrete findings

The project SHALL maintain a documented audit of the "open → operate → back/close → home/library" operation flow for the video, manga/comic, book (PDF/EPUB), audio, and online-novel-reader surfaces, focused on macOS and Windows, produced by change `audit-media-viewer-flow-macos-windows` (GitHub Issue #50). Each finding MUST cite concrete `file_path:line_number` evidence from the current implementation, MUST carry an impact classification (`trap` / `discoverability` / `low` / `structural`), and MUST remain unresolved by this change — resolution happens only via follow-on GitHub Issues / OpenSpec changes that reference the finding by ID.

#### Scenario: Findings are traceable to concrete code locations

- **GIVEN** `design.md` of the `audit-media-viewer-flow-macos-windows` change
- **WHEN** a reader looks up finding F1 (video player back-navigation reachability) or F2 (manga viewer controls/page-turn visibility)
- **THEN** each finding cites at least one `file_path:line_number` reference into the actual `app/lib/features/...` source and states an impact classification

#### Scenario: The audit change itself does not implement fixes

- **GIVEN** the `audit-media-viewer-flow-macos-windows` change's `tasks.md` and git diff
- **WHEN** checking which files were modified
- **THEN** no file under `app/lib/` or `app/test/` is modified by this change; only `openspec/changes/audit-media-viewer-flow-macos-windows/**` files are added

#### Scenario: Existing capability specs are left unchanged

- **GIVEN** the accepted specs `local-video-playback`, `local-manga-zip-viewer`, `local-book-reader`, `local-audio-playback`, `kakuyomu-novel-reader-ui`, and `narou-novel-reader-ui`
- **WHEN** this audit change is applied
- **THEN** none of those specs' requirements are modified; any behavioral requirement change to close a finding is proposed separately in the follow-on change that implements it
