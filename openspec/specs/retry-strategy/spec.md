# retry-strategy Specification

## Purpose
TBD - created by archiving change add-error-ux-infra. Update Purpose after archive.
## Requirements
### Requirement: RetryStrategy sealed hierarchy

The system SHALL define `sealed class RetryStrategy` at `app/lib/core/errors/retry_strategy.dart` with exactly three const factory constructors: `const factory RetryStrategy.indefinite() = _Indefinite;`, `const factory RetryStrategy.bounded(int maxAttempts) = _Bounded;`, and `const factory RetryStrategy.none() = _None;`. The `bounded` constructor MUST throw `ArgumentError` when `maxAttempts < 1`. `RetryStrategy` MUST be usable as a `const` expression where possible.

#### Scenario: bounded(0) throws ArgumentError

- **WHEN** `const RetryStrategy.bounded(0)` is evaluated at runtime
- **THEN** an `ArgumentError` is thrown with a message naming `maxAttempts`

#### Scenario: indefinite and none are const-constructible

- **WHEN** a developer writes `const strategy = RetryStrategy.indefinite();` and `const noop = RetryStrategy.none();`
- **THEN** both expressions compile as constants and no analyzer warning is reported

#### Scenario: Exhaustive switch on RetryStrategy is enforced

- **WHEN** a developer writes a `switch (strategy)` over `RetryStrategy` that omits one of the three variants
- **THEN** the Dart analyzer reports `non_exhaustive_switch_statement`

### Requirement: withRetry executes the task and applies exponential backoff

The system SHALL provide `Future<T> withRetry<T>(Future<T> Function() task, RetryStrategy strategy, { Duration initialDelay = const Duration(seconds: 1), Duration maxDelay = const Duration(minutes: 5), double jitter = 0.2, bool Function(Object error)? shouldRetry })` at `app/lib/core/errors/retry_strategy.dart`. The function MUST invoke `task` once initially. On each thrown error, it MUST invoke `shouldRetry` (or the default predicate) to decide whether to retry. Between attempts it MUST wait `initialDelay * 2^(attempt - 1)` clamped to `maxDelay`, with a uniformly distributed jitter of `±(jitter * delay)`. The default `shouldRetry` predicate MUST return `true` for `RateLimitError`, `UpstreamUnavailableError`, and `NetworkUnreachableError`, and `false` for every other `AppError` variant and for any non-`AppError` throwable.

#### Scenario: Successful first attempt returns immediately

- **GIVEN** a task that returns `42` synchronously
- **WHEN** `withRetry(task, RetryStrategy.bounded(3))` is invoked
- **THEN** the future completes with `42`, the task is invoked exactly once, and no backoff delay is applied

#### Scenario: Three failures then success follow 1s / 2s / 4s waits

- **GIVEN** a task that throws `UpstreamUnavailableError` on attempts 1, 2, 3 and returns `'ok'` on attempt 4
- **WHEN** `withRetry(task, RetryStrategy.bounded(5), initialDelay: Duration(seconds: 1), jitter: 0.0)` is invoked
- **THEN** the waits between attempts are exactly 1s, 2s, and 4s, the task is invoked 4 times, and the future completes with `'ok'`

#### Scenario: bounded(N) gives up after N attempts

- **GIVEN** a task that always throws `RateLimitError(message: 'x')`
- **WHEN** `withRetry(task, RetryStrategy.bounded(3))` is invoked
- **THEN** the task is invoked exactly 3 times and the future completes with an error equal to the last `RateLimitError`

#### Scenario: none retries zero times

- **GIVEN** a task that throws `NetworkUnreachableError(message: 'x')`
- **WHEN** `withRetry(task, RetryStrategy.none())` is invoked
- **THEN** the task is invoked exactly once and the future completes with the `NetworkUnreachableError`

#### Scenario: shouldRetry override is respected

- **GIVEN** a custom predicate `shouldRetry: (e) => e is HtmlParseError`
- **WHEN** `withRetry(task, RetryStrategy.bounded(3), shouldRetry: shouldRetry)` is invoked with a task that throws `HtmlParseError` twice then succeeds
- **THEN** the task is invoked 3 times and the future completes with the success value

### Requirement: withRetry caps each wait at maxDelay

The system SHALL clamp every computed wait between attempts to `maxDelay`. The default `maxDelay` MUST be exactly `Duration(minutes: 5)`. Jitter MUST be applied AFTER clamping so the total wait never exceeds `maxDelay * (1 + jitter)`.

#### Scenario: Long backoff is clamped to 5 minutes

- **GIVEN** `initialDelay: Duration(seconds: 1)` and a task that always throws `UpstreamUnavailableError`
- **WHEN** the 10th retry would compute a delay of 2^9 seconds = 512 seconds
- **THEN** the actual wait before the 10th retry is at most `Duration(minutes: 5) * 1.2 = 360 seconds` (with default jitter 0.2)

#### Scenario: jitter=0 yields exact delays

- **GIVEN** `jitter: 0.0`
- **WHEN** `withRetry` computes the wait for attempt N
- **THEN** the wait is exactly `min(initialDelay * 2^(N-1), maxDelay)` with no randomization

### Requirement: withRetry honors RateLimitError.retryAfter when set

The system SHALL override the calculated exponential backoff delay with `error.retryAfter` whenever the thrown error is a `RateLimitError` with a non-null `retryAfter`. The `retryAfter` value MUST be used verbatim without applying the jitter multiplier.

#### Scenario: retryAfter overrides exponential backoff

- **GIVEN** a task that throws `RateLimitError(message: 'x', retryAfter: Duration(seconds: 30))` then succeeds
- **WHEN** `withRetry(task, RetryStrategy.bounded(2), initialDelay: Duration(seconds: 1), jitter: 0.5)` is invoked
- **THEN** the wait between the first and second attempt is exactly 30 seconds, regardless of `initialDelay` and `jitter`

#### Scenario: retryAfter null falls back to exponential

- **GIVEN** a task that throws `RateLimitError(message: 'x', retryAfter: null)` then succeeds
- **WHEN** `withRetry(task, RetryStrategy.bounded(2), initialDelay: Duration(seconds: 1), jitter: 0.0)` is invoked
- **THEN** the wait between the first and second attempt is exactly 1 second

### Requirement: withRetry default predicate filters non-retriable errors

The system SHALL ensure that, with the default `shouldRetry`, errors of variants `RobotsDisallowedError`, `SiteConsentRequiredError`, `HtmlParseError`, `FileNotFoundError`, `UnsupportedFormatError`, `StorageQuotaError`, and `UnknownError` SHALL NOT trigger a retry. The task MUST be invoked exactly once for these, and the future MUST complete with the original error.

#### Scenario: RobotsDisallowedError is not retried

- **GIVEN** a task that throws `RobotsDisallowedError(message: 'x', path: '/a')`
- **WHEN** `withRetry(task, RetryStrategy.bounded(5))` is invoked
- **THEN** the task is invoked exactly once and the future completes with the `RobotsDisallowedError`

#### Scenario: SiteConsentRequiredError is not retried

- **GIVEN** a task that throws `SiteConsentRequiredError(message: 'x', site: 'kakuyomu')`
- **WHEN** `withRetry(task, RetryStrategy.indefinite())` is invoked
- **THEN** the task is invoked exactly once and the future completes with the `SiteConsentRequiredError`

#### Scenario: Non-AppError throwables are not retried by default

- **GIVEN** a task that throws `FormatException('x')`
- **WHEN** `withRetry(task, RetryStrategy.bounded(3))` is invoked
- **THEN** the task is invoked exactly once and the future completes with the `FormatException`

### Requirement: withRetry indefinite mode never stops by attempt count

The system SHALL allow `RetryStrategy.indefinite()` to keep retrying until either the task succeeds or `shouldRetry` returns `false`. There MUST be no upper bound on the number of attempts. Each wait is still subject to `maxDelay` clamping.

#### Scenario: indefinite keeps retrying past 10 attempts on retriable error

- **GIVEN** a task that throws `RateLimitError(message: 'x')` 12 times then returns `'ok'`
- **WHEN** `withRetry(task, RetryStrategy.indefinite(), initialDelay: Duration(milliseconds: 1), maxDelay: Duration(milliseconds: 1), jitter: 0.0)` is invoked
- **THEN** the task is invoked 13 times and the future completes with `'ok'`

#### Scenario: indefinite stops when shouldRetry returns false

- **GIVEN** a task that throws `NetworkUnreachableError(message: 'x')` once then throws `HtmlParseError(message: 'y')`
- **WHEN** `withRetry(task, RetryStrategy.indefinite())` is invoked with the default predicate
- **THEN** the task is invoked exactly 2 times and the future completes with the `HtmlParseError`

