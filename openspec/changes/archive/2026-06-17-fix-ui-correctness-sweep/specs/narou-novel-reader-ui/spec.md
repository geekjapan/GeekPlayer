## MODIFIED Requirements

### Requirement: Work detail screen with metadata and episode list

The system SHALL provide a work detail screen at `app/lib/features/novel_narou/presentation/work_detail_screen.dart` that displays the work title, author, synopsis, tags, total character count, total episode count, last-updated timestamp, and the full episode list. The screen MUST expose a "Library に追加" button that calls into the shared `LibraryRepository`. The screen MUST resolve and render any narou-specific ruby markup (`|漢字《かんじ》`) in the synopsis. Each episode row MUST show 第N話 as its primary (title) text.

#### Scenario: Metadata fields are populated from the API

- **WHEN** the user opens the detail screen for a work
- **THEN** the title, author, synopsis (with rendered ruby), tags, character count, episode count, and last-updated timestamp are all visible above the episode list within 2 seconds of the screen appearing

#### Scenario: Episode list shows numbered episodes

- **GIVEN** a serialized work with 47 episodes
- **WHEN** the detail screen renders
- **THEN** the episode list shows 47 rows numbered 第1話 through 第47話, each row showing 第N話 as its title

#### Scenario: Short work shows a single episode

- **GIVEN** a 短編 work where the API reports `generalAllNo == 0` (`isShort == true`)
- **WHEN** the detail screen renders
- **THEN** the episode list shows exactly one row, 第1話, rather than an empty list

#### Scenario: Library 追加 triggers the active cache

- **WHEN** the user taps "Library に追加"
- **THEN** a confirmation dialog appears showing the expected download duration (episode count divided by 60, expressed in minutes), and on confirmation `LibraryRepository.addToLibrary(NarouNovelRepository, work.id)` is called and the dialog dismisses

#### Scenario: Ruby markup is rendered as ruby annotations

- **GIVEN** a synopsis containing `|魔王《まおう》`
- **WHEN** the synopsis is rendered
- **THEN** "まおう" appears as ruby above "魔王", and the resolved plain text retains "魔王" without the markup characters
