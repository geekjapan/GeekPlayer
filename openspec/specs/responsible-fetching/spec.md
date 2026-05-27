# responsible-fetching Specification

## Purpose
TBD - created by archiving change add-online-novel-library. Update Purpose after archive.
## Requirements
### Requirement: Per-site RateLimiter (token bucket)

The system SHALL provide a token-bucket `RateLimiter` at `app/lib/core/network/rate_limiter.dart` parameterised by `rate` (tokens per second), `burst` (bucket capacity), and `maxConcurrency` (in-flight task ceiling). Each `Site` MUST be served by its own `RateLimiter` instance. Outbound requests MUST acquire a token via `RateLimiter.run(task)` before being dispatched.

#### Scenario: Bucket drains and refills at the configured rate

- **GIVEN** a `RateLimiter(rate: 0.5, burst: 1, maxConcurrency: 1)` (kakuyomu profile)
- **WHEN** two `run(task)` calls are issued back-to-back
- **THEN** the first task starts immediately and the second task starts no earlier than 2 seconds after the first

#### Scenario: maxConcurrency caps parallelism

- **GIVEN** a `RateLimiter(rate: 1.0, burst: 5, maxConcurrency: 4)` (narou / noc profile)
- **WHEN** ten `run(task)` calls are issued simultaneously while each task takes 1 second
- **THEN** at most 4 tasks are in flight at any instant

#### Scenario: kakuyomu site uses the strict profile

- **WHEN** the dependency injection container provides a `RateLimiter` for `Site.kakuyomu`
- **THEN** that instance has `rate=0.5`, `burst=1`, `maxConcurrency=1` exactly as required by ADR-0001 §取得方針-3

### Requirement: User-Agent header construction

The system SHALL attach a `User-Agent` header to every outbound HTTP request matching the format `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)` where `<version>` comes from `package_info_plus`. The header MUST be set at the `Dio` `BaseOptions` layer so it cannot be omitted by a per-request override.

#### Scenario: User-Agent matches the canonical format

- **WHEN** the app sends any request to narou / noc / kakuyomu
- **THEN** the request's `User-Agent` header equals `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)` and `<version>` is a non-empty semver-shaped string

#### Scenario: Per-request User-Agent override is rejected

- **WHEN** a caller attempts to override `User-Agent` via `Options(headers: {'User-Agent': 'evil'})`
- **THEN** the final outbound header is still the canonical GeekPlayer User-Agent (the interceptor restores it)

### Requirement: robots.txt fetch and enforcement

The system SHALL fetch `/robots.txt` from each `Site` host at most once per 24 hours, parse the `User-agent: *` and `Disallow:` directives, and enforce them before issuing any non-robots request. If the `robots.txt` request itself fails (network error, 4xx, 5xx), the system MUST fail-closed and treat the entire host as disallowed until the next refresh attempt succeeds.

#### Scenario: Disallowed path is blocked

- **GIVEN** a site's `robots.txt` contains `User-agent: *\nDisallow: /private/`
- **WHEN** the system attempts to GET `https://example.com/private/page`
- **THEN** the request is not dispatched and `RobotsDisallowedError` is thrown

#### Scenario: Allowed path proceeds

- **GIVEN** a site's `robots.txt` contains `User-agent: *\nDisallow: /private/` only
- **WHEN** the system attempts to GET `https://example.com/public/page`
- **THEN** the request is dispatched normally

#### Scenario: robots.txt fetch failure fails closed

- **GIVEN** a fresh app start with no cached `robots.txt`
- **WHEN** the GET of `/robots.txt` returns 503
- **THEN** any subsequent `NovelRepository` call for that site throws `RobotsDisallowedError` until the next 24-hour refresh window allows another fetch attempt

#### Scenario: robots cache TTL is 24 hours

- **GIVEN** a successful `robots.txt` fetch occurred at time T
- **WHEN** any request is issued at time T + 23 hours
- **THEN** the cached rules are used without re-fetching
- **WHEN** any request is issued at time T + 25 hours
- **THEN** a fresh `robots.txt` fetch is triggered before the request

### Requirement: Exponential backoff on 429 / 503

The system SHALL retry HTTP responses with status 429 or 503 using exponential backoff: initial 1 second, doubling each attempt, capped at 5 minutes per individual wait, with up to 6 attempts total. A `Retry-After` header value (when present and parseable) MUST override the calculated wait. Each wait MUST include ±20% jitter to avoid synchronised retry storms. Other 4xx / 5xx statuses MUST fail immediately without retry.

#### Scenario: 429 triggers 1s / 2s / 4s waits

- **GIVEN** the server returns 429 on three consecutive attempts then 200 on the fourth
- **WHEN** the client issues a request through the backoff interceptor
- **THEN** the waits between attempts are approximately 1s, 2s, and 4s (within ±20% jitter), and the final response is the 200

#### Scenario: Retry-After overrides the calculated wait

- **GIVEN** the server returns 503 with `Retry-After: 30`
- **WHEN** the backoff interceptor receives this response
- **THEN** the next attempt waits exactly 30 seconds (no jitter applied to explicit Retry-After)

#### Scenario: Maximum total wait is capped at 5 minutes per attempt

- **GIVEN** repeated 503 responses
- **WHEN** the exponential calculation would produce a wait longer than 300 seconds
- **THEN** the wait is clamped to 300 seconds

#### Scenario: 6th retry gives up

- **GIVEN** the server returns 429 on 7 consecutive attempts
- **WHEN** the 7th 429 is received
- **THEN** `RateLimitExceededError` is thrown to the caller and no further attempts are made

#### Scenario: 404 fails immediately

- **WHEN** the server returns 404
- **THEN** the request fails immediately with a `DioException` (no retry, no backoff)

### Requirement: Interceptor ordering

The system SHALL apply request interceptors in the order: `RobotsTxtInterceptor` → `RateLimitInterceptor` → `BackoffInterceptor` → `LoggingInterceptor`. This ordering MUST ensure that disallowed paths short-circuit before a token is consumed, and that backoff waits occur inside the rate-limiter so the queue stays correctly serialised.

#### Scenario: Disallowed path does not consume a rate token

- **GIVEN** a site's `robots.txt` disallows the target path
- **WHEN** a request is issued
- **THEN** `RobotsDisallowedError` is thrown before `RateLimiter.run` acquires a token

#### Scenario: Backoff wait holds the rate-limit slot

- **GIVEN** a 429 response triggers a 2-second backoff wait
- **WHEN** other queued requests for the same site are waiting
- **THEN** those requests do not start during the 2-second wait (the slot is held by the retrying request)

