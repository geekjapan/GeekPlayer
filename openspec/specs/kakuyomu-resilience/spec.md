# kakuyomu-resilience Specification

## Purpose
TBD - created by archiving change add-kakuyomu-novel-reader. Update Purpose after archive.
## Requirements
### Requirement: HTML fixture snapshot tests

The system SHALL include a snapshot test suite under `app/test/features/novel/kakuyomu/` that exercises `KakuyomuHtmlParser` against captured HTML fixtures stored under `app/test/fixtures/kakuyomu/html/`. The suite MUST cover at minimum **5 work pages** (genre-diverse) and **5 episode pages** (length-diverse, ruby with / without), and MUST compare parse output to checked-in golden JSON files. Any difference MUST fail the test with a diff explaining which selector path is affected.

#### Scenario: Parser output matches the golden file

- **WHEN** `KakuyomuHtmlParser.parseEpisodePage` is invoked against `fixtures/kakuyomu/html/episode_001.html`
- **THEN** the resulting `KakuyomuEpisodeBody` serialized to JSON matches `fixtures/kakuyomu/html/episode_001.golden.json` byte-for-byte

#### Scenario: Drift fails the suite with an actionable diff

- **GIVEN** an upstream HTML change shifts an attribute name
- **WHEN** the snapshot test runs in CI
- **THEN** the test fails and the failure message includes the affected fixture path, the expected golden field, and the actual parsed value

### Requirement: RSS fixture snapshot tests

The system SHALL include snapshot tests for `KakuyomuRssSource` against captured RSS / Atom fixtures stored under `app/test/fixtures/kakuyomu/rss/`. The suite MUST cover at minimum the latest feed, the daily ranking feed, and the weekly ranking feed, and MUST compare normalized `KakuyomuFeedItem` lists to checked-in golden JSON files.

#### Scenario: RSS golden comparison

- **WHEN** the latest feed parser is invoked against `fixtures/kakuyomu/rss/latest.xml`
- **THEN** the resulting list of `KakuyomuFeedItem`s matches `fixtures/kakuyomu/rss/latest.golden.json`

### Requirement: Parser failure fallback to official viewer

When `KakuyomuHtmlSource` or `KakuyomuHtmlParser` throws `KakuyomuParseException` (e.g., due to upstream structural change), the reader screen SHALL display a non-blocking fallback panel containing (a) a Japanese error message stating that loading failed, (b) a 「公式ビューアで開く」 button that launches the corresponding Kakuyomu URL in the OS default browser via `url_launcher`, and (c) a 「詳細をコピー」 button that copies a sanitized diagnostic string (failed selector path, request URL, app version, OS name) to the clipboard. The fallback panel MUST NOT crash the app and MUST allow the user to continue browsing other works.

#### Scenario: Parse failure surfaces fallback CTA

- **WHEN** `KakuyomuHtmlSource.fetchEpisodeBody` throws `KakuyomuParseException`
- **THEN** the reader screen replaces its body with the fallback panel containing the official-viewer button and the copy-details button

#### Scenario: Official viewer opens in OS default browser

- **WHEN** the user taps 「公式ビューアで開く」 on the fallback panel for `(workId=W, episodeId=E)`
- **THEN** `url_launcher` is invoked with `https://kakuyomu.jp/works/W/episodes/E` using the platform's external browser mode

#### Scenario: Diagnostic copy excludes user identifiers

- **WHEN** the user taps 「詳細をコピー」
- **THEN** the clipboard receives a string that contains the failed selector path, the request URL, the app version, and the OS name, but does NOT contain any device identifier, the user's IP, or HTML response body

### Requirement: ADR-0001 notice in source docstring

The Dart class `KakuyomuHtmlSource` SHALL carry a class-level docstring (`///`) that reproduces the ADR-0001 operating principles in Japanese: individual use only, active cache only, rate limit (1 req / 2 s, concurrency 1), `robots.txt` respect, 429 / 503 exponential backoff, and the future-policy-change escalation path. The docstring MUST link to ADR-0001 by relative repository path.

#### Scenario: Docstring contains all required notices

- **WHEN** the source file `kakuyomu_html_source.dart` is inspected
- **THEN** the class docstring contains the substrings 「個人利用」, 「能動キャッシュ」, 「1 リクエスト / 2 秒」, 「robots.txt」, 「429」, 「503」, 「ADR-0001」

### Requirement: Kill-switch path for ToS escalation

The system SHALL expose a compile-time boolean flag `kakuyomuEnabled` (default `true`) in `app/lib/core/config/` that, when set to `false`, hides all Kakuyomu UI, refuses to instantiate `KakuyomuNovelRepository`, and on app launch prompts the user to delete any cached Kakuyomu episode bodies. This flag is the kill-switch for the scenario where Kakuyomu's Terms of Service explicitly prohibit automated collection or where the project decides to retreat from HTML parsing.

#### Scenario: Disabling the flag hides Kakuyomu

- **GIVEN** the next release is built with `kakuyomuEnabled = false`
- **WHEN** the user launches that release
- **THEN** no Kakuyomu UI is visible and `KakuyomuNovelRepository` is not registered with any Riverpod provider

#### Scenario: Disabling prompts cache purge on first launch

- **GIVEN** the previous release populated Kakuyomu cached bodies
- **WHEN** the user launches a release with `kakuyomuEnabled = false`
- **THEN** the user is presented with a confirmation dialog explaining the policy change and offering to delete the cached bodies

### Requirement: Production telemetry is local-only

The system SHALL NOT transmit any Kakuyomu parse-failure or rate-limit telemetry to a remote server. Diagnostic information MUST be confined to the local app logs and, on user opt-in, to the user-initiated 「詳細をコピー」 clipboard action described above.

#### Scenario: No remote telemetry endpoint is contacted

- **WHEN** any Kakuyomu parse failure or HTTP error occurs
- **THEN** no HTTP request is dispatched to any host other than `kakuyomu.jp` itself

### Requirement: Manual fixture-refresh procedure documented

The repository SHALL document, under `app/test/fixtures/kakuyomu/README.md`, the manual procedure for refreshing the HTML and RSS fixtures from production Kakuyomu, including the cadence (monthly), the responsible-scraping reminders (single-developer manual fetch, respect rate limit), and how to regenerate the golden JSON files.

#### Scenario: Fixture README exists and is non-empty

- **WHEN** the repository is inspected at `app/test/fixtures/kakuyomu/README.md`
- **THEN** the file exists, is at least 30 lines long, and contains the words 「月 1 回」, 「robots.txt」, and 「golden」

