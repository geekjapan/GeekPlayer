## ADDED Requirements

### Requirement: Kakuyomu consent dialog on first use

The system SHALL display a Kakuyomu-specific consent dialog before any Kakuyomu HTTP request is issued for the first time per device. The dialog MUST clearly communicate the responsible-scraping operating principles from [ADR-0001](../../../../docs/adr/0001-online-novel-fetch-policy.md): individual use only, active-cache-only persistence, rate limiting, `robots.txt` adherence, and the future-policy-change escalation path. The "同意しない" button MUST have visual prominence equivalent to "同意する" (no dark-pattern de-emphasis). Until the user explicitly chooses "同意する", every Kakuyomu UI entry point MUST be hidden or display a disabled-state message linking back to the consent flow.

#### Scenario: First launch shows consent dialog when entering Kakuyomu

- **GIVEN** the user has never granted or denied Kakuyomu consent
- **WHEN** the user taps the Kakuyomu section in the home screen
- **THEN** the consent dialog is displayed, no HTTP request to kakuyomu.jp is dispatched yet, and the user can choose 「同意する」, 「同意しない」, or close

#### Scenario: Decline hides Kakuyomu UI

- **GIVEN** the user tapped 「同意しない」
- **WHEN** the user returns to the home screen
- **THEN** the Kakuyomu section is hidden, and entering it via deep link shows a disabled-state message linking to settings

#### Scenario: Decline does not affect other sites

- **WHEN** the user declines Kakuyomu consent
- **THEN** the narou and noctune sections of the home screen remain fully usable

### Requirement: Settings screen Kakuyomu section

The system SHALL display a Kakuyomu section in the settings screen that includes (a) a consent toggle, (b) the ADR-0001 notice text, (c) the current effective rate-limit configuration, and (d) a link to README's "カクヨム機能の注意事項" section. Turning the toggle OFF MUST prompt a confirmation dialog warning that all cached Kakuyomu episode bodies will be deleted, and on confirmation MUST delete them before flipping the toggle.

#### Scenario: Toggling OFF purges cached bodies

- **GIVEN** the user has 3 Kakuyomu works in `Library` with cached bodies
- **WHEN** the user turns the consent toggle OFF and confirms
- **THEN** all 3 works' cached episode bodies are deleted from the local DB and the Library entries are marked as "本文未取得" until re-consent

#### Scenario: Settings shows the rate-limit configuration

- **WHEN** the settings screen renders the Kakuyomu section
- **THEN** the text "1 リクエスト / 2 秒、並列度 1" is visible verbatim

### Requirement: Search screen

The system SHALL provide a Kakuyomu search screen with a query text field and a results list. Submitting a query MUST call `KakuyomuNovelRepository.search` and render the returned `KakuyomuFeedItem`s as tappable cards (title, author, summary). Tapping a card MUST navigate to the work detail screen for that work.

#### Scenario: Submitting a query renders results

- **WHEN** the user types 「魔法少女」 and submits the search
- **THEN** within 3 seconds the screen renders up to 20 result cards or an empty-state message 「結果が見つかりませんでした」

#### Scenario: Network failure shows retry CTA

- **WHEN** the repository throws `KakuyomuUpstreamUnavailableException`
- **THEN** the screen renders an error card with a "再試行" button and does not crash

### Requirement: Latest feed screen

The system SHALL provide a screen that renders Kakuyomu's official "新着" RSS feed as a chronological list. The screen MUST support pull-to-refresh and MUST honor the shared rate limiter (no rapid back-to-back refreshes within 2 seconds).

#### Scenario: Pull-to-refresh fetches the latest feed

- **WHEN** the user pulls down to refresh
- **THEN** the latest RSS feed is re-fetched (subject to the rate limiter) and the list is updated

#### Scenario: Rapid refreshes are coalesced

- **WHEN** the user triggers pull-to-refresh twice within 1 second
- **THEN** only one network fetch occurs and the second gesture waits for the in-flight result

### Requirement: Ranking screen

The system SHALL provide a ranking screen with four tabs — 日次 / 週次 / 月次 / 累計 — each backed by the corresponding Kakuyomu ranking RSS endpoint. Switching tabs MUST cache the previously loaded tab's items in memory for the session so that returning to a tab does not trigger an immediate refetch.

#### Scenario: Tabs fetch independent ranking feeds

- **WHEN** the user opens the ranking screen and switches between 日次 → 週次 → 月次
- **THEN** each tab dispatches one fetch on first visit (3 fetches total), serialized through the rate limiter

#### Scenario: Returning to a previously loaded tab is instant

- **WHEN** the user switches back to a tab visited earlier in the session
- **THEN** the cached items are rendered immediately and no new fetch is dispatched

### Requirement: Work detail screen

The system SHALL provide a work detail screen that displays the work's title, author, synopsis, tags, episode list (id + title + publishedAt), and a 「Library に追加」 button. Tapping an episode row MUST open the reader screen for that episode. Tapping 「Library に追加」 MUST persist the work in `Library` and trigger active caching of all currently published episode bodies.

#### Scenario: Library add caches all episodes

- **GIVEN** a work has 12 published episodes
- **WHEN** the user taps 「Library に追加」 and the action confirms
- **THEN** all 12 episode bodies are fetched (subject to the rate limiter, so it takes at least 22 seconds) and stored

#### Scenario: Library add can be canceled mid-fetch

- **WHEN** the user taps a cancel button while the multi-episode caching is in progress
- **THEN** the in-flight fetch completes but no further fetches are dispatched and the work is removed from `Library`

### Requirement: Reader screen

The system SHALL provide an episode reader screen that renders the parsed episode body with paragraphs, blank lines, and ruby spans preserved. The screen MUST persist the reader scroll position via `ResumePoint` keyed by `(workId, episodeId)` and MUST provide navigation to the previous and next episodes within the same work.

#### Scenario: Resume position is restored

- **GIVEN** the user previously read an episode to 40 % scroll
- **WHEN** the user reopens that episode
- **THEN** the reader scrolls to within ±2 % of the saved position

#### Scenario: Ruby is rendered

- **WHEN** an episode body contains `<ruby>漢字<rt>かんじ</rt></ruby>`
- **THEN** the reader renders the base text with its ruby gloss visible above

#### Scenario: Previous / next episode navigation

- **WHEN** the user taps "次のエピソード"
- **THEN** the reader screen replaces its content with the next episode (cached if Library, fetched otherwise) without leaving the reader screen

### Requirement: Hidden Kakuyomu UI when consent is revoked

When the user revokes Kakuyomu consent at any time, the system SHALL immediately hide all Kakuyomu UI entry points (home section, search, ranking, latest feed, work detail, reader). In-flight Kakuyomu HTTP requests MUST be cancelled. Library entries for Kakuyomu works MUST become read-only stubs labeled 「本文は再同意後に再取得します」.

#### Scenario: Revoking consent hides UI immediately

- **GIVEN** the user is on the Kakuyomu work detail screen
- **WHEN** the user navigates to settings and turns the consent toggle OFF
- **THEN** the next frame does not render any Kakuyomu UI and the user is navigated back to the home screen

#### Scenario: In-flight requests are cancelled on revoke

- **WHEN** consent is revoked while a fetch is in flight
- **THEN** the Dio CancelToken is invoked and the fetch resolves to a cancellation, not a successful body write
