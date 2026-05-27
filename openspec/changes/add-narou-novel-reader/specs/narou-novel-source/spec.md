## ADDED Requirements

### Requirement: NarouNovelRepository implements the shared NovelRepository contract for the general site

The system SHALL provide `NarouNovelRepository` at `app/lib/features/novel_narou/data/narou_novel_repository.dart` that implements the `NovelRepository` interface defined by `add-online-novel-library`. The repository MUST target the general endpoint `https://api.syosetu.com/novelapi/api/` and MUST expose search, ranking, work detail, and episode body retrieval. The repository MUST be instantiable without a `SiteConsent` because the general 小説家になろう site does not require an explicit age gate.

#### Scenario: Searching for works returns the shared Work model

- **WHEN** `NarouNovelRepository.search(NarouSearchOptions(keyword: '魔法', genres: {NarouGenre.fantasy}))` is called
- **THEN** the repository SHALL issue a GET against `https://api.syosetu.com/novelapi/api/` with `out=json`, the keyword as `word=魔法`, and `genre=201` (or the corresponding numeric code), and SHALL return a `List<Work>` populated with `Site.narou`

#### Scenario: Empty result returns an empty list, not an error

- **WHEN** the upstream API responds with `allcount: 0` and no work entries
- **THEN** the repository SHALL return an empty `List<Work>` and SHALL NOT throw

#### Scenario: Work detail fetch by ncode returns the merged metadata

- **WHEN** `NarouNovelRepository.fetchWork(WorkId(Site.narou, 'n4830bu'))` is called
- **THEN** the repository SHALL issue a GET with `ncode=n4830bu&out=json` and SHALL return a `Work` populated with `episodeCount` equal to the API's `general_all_no`; the actual `Episode` instances are retrieved separately via `fetchEpisodes(WorkId)`

### Requirement: NarouR18NovelRepository targets the R18 endpoint and refuses construction without consent

The system SHALL provide `NarouR18NovelRepository` at `app/lib/features/novel_narou/data/narou_r18_novel_repository.dart` targeting `https://api.syosetu.com/novel18api/api/`. The repository MUST refuse instantiation when no granted `SiteConsent` exists for `Site.noc`, by throwing `StateError`. The repository MUST observe `SiteConsentRepository` changes and SHALL release internal resources when the consent is revoked.

#### Scenario: Construction without consent throws

- **GIVEN** no `SiteConsent` is granted for `Site.noc`
- **WHEN** `NarouR18NovelRepository(...)` is constructed
- **THEN** a `StateError` is thrown with a message identifying the missing consent

#### Scenario: Construction after consent succeeds

- **GIVEN** the user has previously granted consent for `Site.noc` via the `AgeGateDialog`
- **WHEN** `NarouR18NovelRepository(...)` is constructed
- **THEN** the instance is returned and a follow-up call to `search` succeeds without throwing

#### Scenario: Revoking consent invalidates the repository

- **GIVEN** an active `NarouR18NovelRepository` instance
- **WHEN** `SiteConsentRepository.revoke(Site.noc)` is called
- **THEN** subsequent calls on the repository SHALL throw `StateError`, and any Riverpod provider holding the repository SHALL be invalidated within 1 second

### Requirement: Shared low-level NarouApiClient with rate-limited dio

The system SHALL provide `NarouApiClient` at `app/lib/features/novel_narou/data/narou_api_client.dart` that wraps a single `Dio` instance and routes through the shared `RateLimiter` keyed on `api.syosetu.com`. Both general and R18 repositories MUST share the same rate-limit bucket because they target the same origin. The client MUST set the `User-Agent` header to `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)` on every request.

#### Scenario: General and R18 requests share the same rate-limit bucket

- **GIVEN** the rate limit is configured at 1 request per second on `api.syosetu.com`
- **WHEN** a search on the general endpoint and a search on the R18 endpoint are issued at the same instant
- **THEN** the second request is delayed by approximately 1 second relative to the first, regardless of which endpoint was first

#### Scenario: Every outgoing request carries the policy User-Agent

- **WHEN** any request is issued via `NarouApiClient`
- **THEN** the outgoing `User-Agent` header value matches the regular expression `^GeekPlayer/\d+\.\d+\.\d+ \(\+https://github\.com/geekjapan/GeekPlayer; personal-use\)$`

#### Scenario: 429 triggers exponential backoff up to 5 minutes

- **GIVEN** the upstream returns HTTP 429 on the first attempt
- **WHEN** `NarouApiClient` retries the request
- **THEN** retry delays SHALL follow exponential backoff (1s, 2s, 4s, 8s, ...), MUST cap at 5 minutes, and SHALL stop after the configured retry limit (default 5)

#### Scenario: 503 is treated identically to 429

- **GIVEN** the upstream returns HTTP 503
- **WHEN** `NarouApiClient` retries
- **THEN** the same exponential backoff schedule applies and recovery on 200 yields the response transparently to the caller

### Requirement: Ranking retrieval combines rankget with detail batch fetch

The system SHALL provide ranking retrieval for the types daily, weekly, monthly, quarterly, yearly, and all-time via `NarouRankingRepository.fetchRanking(NarouRankingType, DateTime)`. The repository MUST first call the `rankget` endpoint to obtain ranked `ncode` identifiers and ranks, then SHALL batch-fetch detailed metadata for the top 100 entries by passing dash-separated `ncode` to the detail endpoint in a single call. The combined response MUST be returned in rank order.

#### Scenario: Daily ranking returns rank-ordered works

- **WHEN** `NarouRankingRepository.fetchRanking(NarouRankingType.daily, DateTime(2026, 5, 27))` is called
- **THEN** the result is a `List<RankedWork>` of length up to 100, sorted ascending by `rank`, with each entry carrying both the `Work` metadata and the original `pt` (point) value from `rankget`

#### Scenario: Missing detail for a ranked ncode is tolerated

- **GIVEN** `rankget` returns 100 ncodes but the batched detail endpoint returns metadata for only 97 of them
- **WHEN** the ranking is assembled
- **THEN** the 3 missing entries SHALL be filtered out and a structured log entry SHALL be written, but the call SHALL succeed and return the 97 works

### Requirement: Narou body fetching is isolated in NarouEpisodeFetcher

The system SHALL provide `NarouEpisodeFetcher` at `app/lib/features/novel_narou/data/narou_episode_fetcher.dart` exposing `Future<String> fetchBody(String ncode, int episodeIndex)`. The fetcher MUST hide the difference between short-form and serialized works behind this single method. The fetcher MUST go through the same `RateLimiter` bucket as `NarouApiClient`.

#### Scenario: Short-form work fetches body via API

- **GIVEN** a work whose `novel_type` is short (single-chapter)
- **WHEN** `NarouEpisodeFetcher.fetchBody(ncode, 1)` is called
- **THEN** the fetcher SHALL issue the API request path documented in `design.md` Q-D1 short-form arm, and SHALL return the raw body text

#### Scenario: Serialized work fetches body via episode URL

- **GIVEN** a work whose `novel_type` is serialized
- **WHEN** `NarouEpisodeFetcher.fetchBody(ncode, episodeIndex)` is called for a valid episode index
- **THEN** the fetcher SHALL fetch the page documented in `design.md` Q-D1 serialized arm, SHALL extract the body section, and SHALL return the text

#### Scenario: Body fetch respects the shared rate limit

- **GIVEN** 50 sequential calls to `fetchBody` are queued in a tight loop
- **WHEN** the queue is processed
- **THEN** the actual outgoing request rate SHALL NOT exceed 1 request per second sustained across the origin `api.syosetu.com` and `ncode.syosetu.com` combined

### Requirement: NarouSearchOptions extends the shared query model

The system SHALL define `NarouSearchOptions` at `app/lib/features/novel_narou/domain/narou_work_query.dart` as a subclass of the shared `WorkQuery` defined by `add-online-novel-library`. The extensions MUST cover genre selection (multi-select from `NarouGenre`), minimum and maximum character counts, last-update date range, completed flag, pickup flag, and long-running flag. Each field MUST be optional; only the keyword on the parent `WorkQuery` is mandatory when no extension fields are set.

#### Scenario: Genre multi-select maps to comma-joined codes

- **WHEN** `NarouSearchOptions(genres: {NarouGenre.fantasy, NarouGenre.scifi})` is converted to query parameters
- **THEN** the produced `genre` parameter is the comma-joined string of numeric codes (e.g., `201-301`) in stable ascending order

#### Scenario: Character range maps to length parameter

- **WHEN** `NarouSearchOptions(minChars: 50000, maxChars: 200000)` is converted to query parameters
- **THEN** the produced `length` parameter equals `50000-200000`

#### Scenario: Last-updated-after maps to lastup parameter

- **WHEN** `NarouSearchOptions(lastUpdatedAfter: DateTime(2026, 1, 1))` is converted
- **THEN** the produced `lastup` parameter encodes the unix timestamp lower bound matching the API specification

### Requirement: Defensive mapping tolerates upstream schema drift

The system SHALL implement response mappers that accept missing or unknown fields without throwing. Required fields SHALL be limited to `ncode` and `title`; all other fields SHALL be treated as optional and default to safe null / empty values. Unknown fields SHALL be silently ignored. The mappers MUST be covered by snapshot tests against captured API responses in `app/test/fixtures/narou/`.

#### Scenario: Missing optional field does not crash

- **GIVEN** an API response omits the `keyword` field for a work
- **WHEN** the mapper builds a `Work`
- **THEN** the resulting `Work.tags` is an empty list and no exception is raised

#### Scenario: Missing required ncode raises a typed error

- **GIVEN** an API response includes a work entry with no `ncode`
- **WHEN** the mapper processes it
- **THEN** a `NarouResponseError` (with the offending entry index) is thrown and structured-logged
