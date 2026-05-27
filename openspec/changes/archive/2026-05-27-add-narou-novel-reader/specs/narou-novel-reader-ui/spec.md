## ADDED Requirements

### Requirement: Narou home section on the home screen

The home screen SHALL expose a "なろう" section composed via the shared `NovelHomeSection` interface from `add-online-novel-library`. The section MUST present three entry points: a search box, a ranking shortcut (with type selector for daily / weekly / monthly), and a pickup shortcut. When the user has not granted R18 consent, the section MUST NOT show any R18-only entry points; an R18 tab MAY appear only after consent is granted.

#### Scenario: First-run state shows general entry points only

- **GIVEN** the app is launched for the first time and no `SiteConsent` for `Site.noc` exists
- **WHEN** the home screen renders the なろう section
- **THEN** the search box, ranking shortcut, and pickup shortcut are visible, and no R18 tab is shown

#### Scenario: Granting R18 consent reveals the R18 tab

- **GIVEN** the user opens the なろう section and taps the "ノクターン" entry point
- **WHEN** the user completes the `AgeGateDialog` with "はい"
- **THEN** the R18 tab is added to the section and selected, and the listing loads R18 works

### Requirement: Search screen with narou-specific filters

The system SHALL provide a search screen at `app/lib/features/novel_narou/presentation/search_screen.dart` that accepts a free-text keyword and narou-specific filters (genre multi-select, character-count range, last-update date range, completed flag, pickup flag). Submitting the form MUST issue a single API request through `NarouNovelRepository.search`, and results MUST be displayed as an infinite-scroll list paginated in pages of 20 entries.

#### Scenario: Keyword search returns results

- **WHEN** the user types "魔法" in the keyword box and taps 検索
- **THEN** the result list shows up to 20 works whose title or keyword field matches "魔法", ordered by the default API ordering, within 3 seconds on a typical broadband connection

#### Scenario: Empty result shows placeholder

- **GIVEN** a search whose API response has `allcount: 0`
- **WHEN** the result is rendered
- **THEN** a placeholder message ("該当する作品が見つかりませんでした") is displayed and the list view is hidden

#### Scenario: Infinite scroll loads the next page

- **GIVEN** the search has more than 20 matching works and 20 are currently rendered
- **WHEN** the user scrolls to within 200 pixels of the bottom of the list
- **THEN** the next 20 works are fetched and appended, with a loading spinner shown during the fetch

#### Scenario: Filter chips reflect the active query

- **GIVEN** the user has selected fantasy and scifi genres, min 50,000 chars, and the completed flag
- **WHEN** the search results screen is shown
- **THEN** three filter chips are visible above the result list, and tapping a chip's X icon removes that filter and re-runs the search

### Requirement: Ranking screen with type selector

The system SHALL provide a ranking screen at `app/lib/features/novel_narou/presentation/ranking_screen.dart` with tabs for daily, weekly, monthly, quarterly, yearly, and all-time rankings. Switching tabs MUST trigger a fetch via `NarouRankingRepository`. The list MUST display rank, title, author, and points, and tapping an entry MUST open the work detail screen.

#### Scenario: Daily tab loads daily ranking

- **WHEN** the user opens the ranking screen and the daily tab is the default selection
- **THEN** the top 100 works for today's date are listed in rank order, each row showing rank position, title, author name, and point value

#### Scenario: Switching tabs refreshes the list

- **GIVEN** the user is viewing the daily ranking
- **WHEN** the user taps the 週間 tab
- **THEN** the list is replaced with the weekly ranking via a new call to `NarouRankingRepository`, and a loading indicator is shown during the fetch

#### Scenario: Tapping an entry opens the work detail

- **WHEN** the user taps any ranking row
- **THEN** the work detail screen for that `ncode` is pushed onto the navigation stack

### Requirement: Work detail screen with metadata and episode list

The system SHALL provide a work detail screen at `app/lib/features/novel_narou/presentation/work_detail_screen.dart` that displays the work title, author, synopsis, tags, total character count, total episode count, last-updated timestamp, and the full episode list. The screen MUST expose a "Library に追加" button that calls into the shared `LibraryRepository`. The screen MUST resolve and render any narou-specific ruby markup (`|漢字《かんじ》`) in the synopsis.

#### Scenario: Metadata fields are populated from the API

- **WHEN** the user opens the detail screen for a work
- **THEN** the title, author, synopsis (with rendered ruby), tags, character count, episode count, and last-updated timestamp are all visible above the episode list within 2 seconds of the screen appearing

#### Scenario: Episode list shows numbered episodes

- **GIVEN** a serialized work with 47 episodes
- **WHEN** the detail screen renders
- **THEN** the episode list shows 47 rows numbered 第1話 through 第47話, each row showing the chapter title (if any) and the per-episode update date

#### Scenario: Library 追加 triggers the active cache

- **WHEN** the user taps "Library に追加"
- **THEN** a confirmation dialog appears showing the expected download duration (episode count divided by 60, expressed in minutes), and on confirmation `LibraryRepository.addToLibrary(NarouNovelRepository, work.id)` is called and the dialog dismisses

#### Scenario: Ruby markup is rendered as ruby annotations

- **GIVEN** a synopsis containing `|魔王《まおう》`
- **WHEN** the synopsis is rendered
- **THEN** "まおう" appears as ruby above "魔王", and the resolved plain text retains "魔王" without the markup characters

### Requirement: Reader screen with vertical scroll and adjustable typography

The system SHALL provide a reader screen at `app/lib/features/novel_narou/presentation/reader_screen.dart` that renders a single episode body as a vertically scrolling, selectable text. The reader MUST expose controls for font size (12 - 32 pt in 2 pt steps), line height (1.2 - 2.4 in 0.2 steps), and color theme (light / sepia / dark). Settings MUST be persisted across reader sessions. The reader MUST show next-episode and previous-episode navigation buttons when adjacent episodes exist.

#### Scenario: Default settings apply on first open

- **GIVEN** the user opens the reader for the first time
- **WHEN** the reader screen appears
- **THEN** the font size is 16 pt, line height is 1.6, and color theme is light, matching the documented defaults

#### Scenario: Changing font size persists across episodes

- **GIVEN** the user is in the reader and changes the font size to 20 pt
- **WHEN** the user navigates to the next episode and back
- **THEN** the font size remains 20 pt across both navigations

#### Scenario: Settings persist across app restarts

- **GIVEN** the user has set font size 18, line height 2.0, theme dark, and has closed the reader and quit the app
- **WHEN** the user re-launches the app and opens any reader
- **THEN** the reader renders with font size 18, line height 2.0, dark theme

#### Scenario: Selectable text supports copy

- **WHEN** the user long-presses on the body text and selects a range
- **THEN** the OS native copy menu appears and copying yields the plain text without ruby markup characters

#### Scenario: Next-episode navigation skips ahead

- **GIVEN** the user is reading episode 5 of a work with 10 episodes
- **WHEN** the user taps the next-episode button
- **THEN** the reader loads episode 6, scroll position resets to 0, and the previous-episode button becomes active

#### Scenario: Last-episode navigation hides the next button

- **GIVEN** the user is reading the final episode
- **WHEN** the reader renders
- **THEN** the next-episode button is hidden or disabled, and only the previous-episode button is interactive

### Requirement: Scroll-position bookmark per episode

The reader SHALL persist the current scroll offset per `(workId, episodeIndex)` tuple to the shared `novel_bookmarks` storage on every navigation away from the screen. On re-entry, the reader MUST restore the saved scroll offset within 500 ms of the screen first being painted, unless the saved offset would land within 5% of the bottom of the body — in which case the reader MUST reset to position 0.

#### Scenario: Reader resumes from saved scroll position

- **GIVEN** a previously saved scroll offset of 1200 px for episode 3 of a work
- **WHEN** the user opens episode 3 of that work
- **THEN** the reader scrolls to offset 1200 within 500 ms of first paint

#### Scenario: Near-end resume restarts the episode

- **GIVEN** the saved offset is 4960 px in a 5000 px body
- **WHEN** the user re-opens the episode
- **THEN** the reader starts at offset 0

#### Scenario: Leaving the screen saves the current offset

- **GIVEN** the user is currently scrolled to 800 px in episode 2
- **WHEN** the user navigates back or taps the next-episode button
- **THEN** offset 800 is written to `novel_bookmarks` for `(workId, 2)` before the new screen is rendered
