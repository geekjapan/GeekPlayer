## ADDED Requirements

### Requirement: Kakuyomu RSS / Atom feed source

The system SHALL provide a `KakuyomuRssSource` that fetches Kakuyomu's official RSS / Atom feeds for search, latest works, ranking (daily / weekly / monthly / cumulative), and work-update notifications, and SHALL normalize the results into `KakuyomuFeedItem` value objects regardless of whether the upstream feed is RSS 2.0 or Atom. Parsing MUST be delegated to `webfeed_revised`. Per-item parse failures MUST NOT abort the entire feed; failed items MUST be skipped with a logged warning.

#### Scenario: Search feed returns normalized items

- **WHEN** `KakuyomuRssSource.search('魔法少女')` is called and Kakuyomu returns an RSS 2.0 feed with 20 items
- **THEN** the source returns up to 20 `KakuyomuFeedItem`s with `title`, `workId`, `url`, `author`, `publishedAt`, and `summary` populated

#### Scenario: Atom and RSS are both accepted

- **WHEN** the upstream endpoint serves an Atom feed instead of RSS 2.0 (detected via `Content-Type`)
- **THEN** the source still returns normalized `KakuyomuFeedItem`s without crashing

#### Scenario: One malformed item does not abort the feed

- **WHEN** a feed contains one item whose `link` element is missing
- **THEN** the malformed item is skipped, the remaining items are returned, and a warning is emitted via the app logger

### Requirement: Kakuyomu HTML source

The system SHALL provide a `KakuyomuHtmlSource` that fetches Kakuyomu work pages (`/works/{workId}`) and episode pages (`/works/{workId}/episodes/{episodeId}`), and SHALL delegate HTML parsing to `KakuyomuHtmlParser`. The class docstring MUST contain a Japanese notice that mirrors ADR-0001 (individual use only, active cache only, rate limit, `robots.txt`, future ToS-change escalation).

#### Scenario: Fetch and parse a work page

- **WHEN** `KakuyomuHtmlSource.fetchWork('1177354054881131863')` is called and the server returns a 200 OK HTML response
- **THEN** the source returns a `KakuyomuWorkDetail` containing `title`, `author`, `synopsis`, `tags`, `episodes` list (id + title + publishedAt), and `lastUpdatedAt`

#### Scenario: Fetch and parse an episode body

- **WHEN** `KakuyomuHtmlSource.fetchEpisodeBody(workId, episodeId)` is called
- **THEN** the source returns a `KakuyomuEpisodeBody` with normalized paragraph segments (paragraph, blank line, ruby span)

#### Scenario: 404 from an episode page is mapped to a typed exception

- **WHEN** the server returns 404 for an episode URL
- **THEN** the source throws `KakuyomuEpisodeNotFoundException` instead of a raw `DioException`

### Requirement: Responsible scraping rate limit

All HTTP requests issued by `KakuyomuRssSource` and `KakuyomuHtmlSource` SHALL be serialized at a minimum interval of **2 seconds between requests** with **concurrency 1**, by going through the shared `RateLimiter` declared by `add-online-novel-library` under the site key `'kakuyomu'`. Requests MUST NOT bypass the limiter under any code path, including retries.

#### Scenario: Two back-to-back requests are spaced out

- **WHEN** two Kakuyomu HTTP requests are dispatched in rapid succession
- **THEN** the second request begins network I/O no earlier than 2 seconds after the first request started

#### Scenario: Parallel calls are serialized

- **WHEN** three concurrent Kakuyomu requests are launched
- **THEN** they execute sequentially in submission order, each waiting for the previous to release the limiter

### Requirement: User-Agent identification

Every Kakuyomu request SHALL include a User-Agent header of exactly the form `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)`, where `<version>` is the app's semantic version obtained at runtime from package metadata.

#### Scenario: User-Agent header is set on outgoing requests

- **WHEN** any Kakuyomu request is dispatched
- **THEN** the `User-Agent` request header matches the regular expression `^GeekPlayer/\d+\.\d+\.\d+(?:[-+][\w.-]+)? \(\+https://github\.com/geekjapan/GeekPlayer; personal-use\)$`

### Requirement: robots.txt enforcement

The system SHALL fetch `https://kakuyomu.jp/robots.txt` on first use of the Kakuyomu feature and cache the parsed disallow rules in process memory for **24 hours** (aligned with the shared `responsible-fetching` policy). All Kakuyomu HTTP requests SHALL be evaluated against the cached rules before dispatch; requests matching a disallow pattern MUST throw `RobotsDisallowedException` without performing network I/O. If `robots.txt` cannot be fetched, the source MUST fall back to a hard-coded allowlist (`/works/{id}`, `/works/{id}/episodes/{id}`, and known RSS endpoints) and MUST NOT silently allow arbitrary paths.

#### Scenario: Disallowed path is blocked before network I/O

- **GIVEN** the cached `robots.txt` disallows `/admin/`
- **WHEN** a request to `https://kakuyomu.jp/admin/foo` is attempted
- **THEN** `RobotsDisallowedException` is thrown and no HTTP request is sent

#### Scenario: robots.txt fetch failure falls back to allowlist

- **GIVEN** `robots.txt` cannot be fetched (e.g., 503) and no previous successful cache exists
- **WHEN** a request to a work page (`/works/123`) is attempted
- **THEN** the request proceeds (allowlisted), but a request to an unlisted path is rejected with `RobotsDisallowedException`

#### Scenario: robots.txt cache expires after 24 hours

- **GIVEN** the `robots.txt` cache was populated 25 hours ago
- **WHEN** the next Kakuyomu request is evaluated
- **THEN** `robots.txt` is re-fetched before evaluation

### Requirement: Exponential backoff on 429 / 503

When a Kakuyomu HTTP response is **429 Too Many Requests** or **503 Service Unavailable**, the source SHALL retry the request with exponential backoff: initial delay 1 second, doubling each attempt, capped at **5 minutes** per delay. The `Retry-After` response header (delta-seconds or HTTP-date) MUST override the computed delay if present. After **6 failed retries** (aligned with `add-online-novel-library/responsible-fetching`), the source MUST surface `KakuyomuUpstreamUnavailableException` and stop retrying.

#### Scenario: First retry waits at least 1 second

- **WHEN** the server returns 429 on the first attempt
- **THEN** the source waits at least 1 second before retrying

#### Scenario: Retry-After header is honored

- **WHEN** the server returns 503 with `Retry-After: 30`
- **THEN** the source waits at least 30 seconds before retrying, regardless of the exponential schedule

#### Scenario: Backoff is capped at 5 minutes

- **WHEN** computed exponential delay would exceed 300 seconds
- **THEN** the actual delay is exactly 300 seconds

#### Scenario: Give up after 6 retries

- **WHEN** all 6 retries return 429
- **THEN** `KakuyomuUpstreamUnavailableException` is thrown and propagated to the UI layer

### Requirement: KakuyomuNovelRepository satisfies the shared NovelRepository interface

The system SHALL provide `KakuyomuNovelRepository` that implements the `NovelRepository` interface defined by `add-online-novel-library`. The repository MUST compose `KakuyomuRssSource` and `KakuyomuHtmlSource`, and every method MUST check `SiteConsentRepository.isGranted(Site.kakuyomu)` before issuing any HTTP request.

#### Scenario: Repository composes RSS for search and HTML for work detail

- **WHEN** `repository.search(query)` and `repository.fetchWork(workId)` are called
- **THEN** the former invokes `KakuyomuRssSource.search` and the latter invokes `KakuyomuHtmlSource.fetchWork`, with no other source being consulted

#### Scenario: Consent denied short-circuits all repository methods

- **GIVEN** `SiteConsentRepository.isGranted(Site.kakuyomu)` returns false
- **WHEN** any method of `KakuyomuNovelRepository` is called
- **THEN** `SiteConsentDeniedException` is thrown before any HTTP request is dispatched

### Requirement: Active cache only

The repository SHALL persist Kakuyomu episode bodies to local storage **only** when the user explicitly adds the parent work to the `Library`. Read-only reader sessions MUST NOT write to the body cache. Passive crawling, prefetching, mirroring, and "read-ahead" prefetches are prohibited.

#### Scenario: Reading without library add does not cache

- **GIVEN** a work is not in the user's `Library`
- **WHEN** the user opens an episode reader screen and the body is fetched
- **THEN** no episode-body row is written to the local DB

#### Scenario: Library add caches all current episodes

- **WHEN** the user adds a work to `Library`
- **THEN** every currently published episode's body is fetched (respecting the rate limiter) and persisted to the local DB
