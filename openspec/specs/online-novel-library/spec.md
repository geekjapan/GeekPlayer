# online-novel-library Specification

## Purpose
TBD - created by archiving change add-online-novel-library. Update Purpose after archive.
## Requirements
### Requirement: NovelRepository abstraction

The system SHALL provide a `NovelRepository` interface at `app/lib/core/novel/novel_repository.dart` that abstracts online novel sources behind a `Site` identifier. The interface MUST expose `fetchWork`, `fetchEpisodes` (as `Stream<Episode>`), and `fetchEpisodeBody` operations, and MUST be implementable by site-specific repositories without exposing site-specific types to callers.

#### Scenario: Concrete repository declares its Site

- **WHEN** a class implements `NovelRepository`
- **THEN** the analyzer enforces that the `site` getter returns a non-null `Site` value, and the implementation appears in the dependency-injection registry keyed by that `Site`

#### Scenario: fetchEpisodes streams progressively

- **GIVEN** a `NovelRepository` is asked to fetch episodes for a `Work` that has 100 episodes
- **WHEN** the consumer subscribes to `fetchEpisodes(workId)`
- **THEN** the stream emits each `Episode` as it becomes available without buffering the entire list in memory, and emits `done` after the last episode

#### Scenario: fetchEpisodeBody is pure (no persistence)

- **WHEN** `fetchEpisodeBody(workId, episodeId)` is called outside of a Library add flow
- **THEN** the returned `EpisodeBody` is in-memory only and no row is inserted into `novel_episodes`

### Requirement: Site / Work / Episode domain model

The system SHALL define `Site`, `WorkId`, `Work`, `EpisodeId`, `Episode`, and `EpisodeBody` as immutable value objects in `app/lib/core/novel/models/`. `Site` MUST be a finite enum covering at minimum `narou`, `noc`, and `kakuyomu`. `WorkId` MUST be a composite of `(Site site, String externalId)` and MUST be equality-comparable.

#### Scenario: WorkId equality is structural

- **WHEN** two `WorkId` instances are constructed with the same `site` and `externalId`
- **THEN** `a == b` is `true` and `a.hashCode == b.hashCode`

#### Scenario: Work carries episode count and metadata

- **WHEN** a `Work` value is constructed
- **THEN** it MUST carry at minimum `id (WorkId)`, `title`, `author`, `episodeCount`, and optional `synopsis`

#### Scenario: Site enum is exhaustively switchable

- **WHEN** code performs `switch (site) { case Site.narou: ... case Site.noc: ... case Site.kakuyomu: ... }`
- **THEN** the analyzer reports the switch as exhaustive without a default clause

### Requirement: Library add flow (active caching)

The system SHALL persist a `Work` and all of its `Episode` bodies into the `novel_works` and `novel_episodes` tables only when the user explicitly invokes the "Library に追加" action. Passive caching during browsing MUST NOT occur. The flow MUST be idempotent: re-running it on a partially saved Work resumes from the next missing episode.

#### Scenario: Add to Library persists work and episodes

- **GIVEN** a user is viewing a `Work` from `narou` that has 3 episodes
- **WHEN** the user taps "Library に追加"
- **THEN** one row is inserted into `novel_works` with `(site='narou', externalId=<id>)`, and 3 rows are inserted into `novel_episodes` with `episodeIndex` 1..3 and the body text populated

#### Scenario: Browsing without adding does not cache

- **WHEN** the user views an `Episode` of a `Work` that is not in the Library
- **THEN** no row is written to `novel_episodes` for that Work, and `novel_works` remains unchanged

#### Scenario: Resume partial Library add

- **GIVEN** a previous "Library に追加" run for a 10-episode Work succeeded for episodes 1..4 then failed on episode 5
- **WHEN** the user invokes "Library に追加" on the same Work again
- **THEN** episodes 1..4 are not re-fetched, and `fetchEpisodeBody` is called only for episodes 5..10

#### Scenario: Removing from Library deletes cached bodies

- **WHEN** the user removes a Work from the Library
- **THEN** the corresponding rows in `novel_works`, `novel_episodes`, and `novel_bookmarks` are deleted in a single transaction

### Requirement: NovelHomeSection on the home screen

The home screen SHALL display a `NovelHomeSection` that lists Library entries grouped or filterable by `Site`. Each entry MUST show at minimum the `Work` title, author, site badge, and current bookmark position. The section MUST render an empty-state placeholder when the Library has no Works. The empty-state placeholder MUST NOT render a permanently disabled action button as a feature placeholder.

#### Scenario: Empty Library shows placeholder

- **WHEN** the home screen is displayed and `novel_works` is empty
- **THEN** the `NovelHomeSection` shows the placeholder "Library に小説はまだありません" and no permanently disabled "検索画面を開く" button

#### Scenario: Site filter chips narrow the listing

- **GIVEN** the Library contains 3 narou Works and 1 kakuyomu Work
- **WHEN** the user taps the "narou" filter chip
- **THEN** only the 3 narou Works are visible; tapping "すべて" restores all 4

#### Scenario: Tapping a Work entry opens the reader

- **WHEN** the user taps a Library entry
- **THEN** the system opens the reader screen for that Work, restoring the bookmark recorded in `novel_bookmarks` (defaulting to episode 1, scrollFraction 0 if absent)

### Requirement: Bookmark persistence

The system SHALL persist exactly one "current reading position" per `Work` in the `novel_bookmarks` table, keyed by `(site, externalId)`. The position MUST consist of `episodeIndex` (1-based) and `scrollFraction` (0.0..1.0). Updates MUST be debounced to at most one write per 2 seconds while the user is reading.

#### Scenario: Bookmark is written when leaving the reader

- **WHEN** the user exits the reader screen for a Library Work
- **THEN** the current `(episodeIndex, scrollFraction)` is written to `novel_bookmarks` via upsert before the screen is destroyed

#### Scenario: Bookmark debounces during continuous scroll

- **WHEN** the user scrolls continuously for 10 seconds
- **THEN** at most 5 writes are issued to `novel_bookmarks` during that window

#### Scenario: Reopening a Work resumes from bookmark

- **GIVEN** `novel_bookmarks` contains `(site='kakuyomu', externalId='abc', episodeIndex=7, scrollFraction=0.42)`
- **WHEN** the user reopens that Work from the home screen
- **THEN** the reader opens episode 7 and scrolls to 42% of the episode body
