## MODIFIED Requirements

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
