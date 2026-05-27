import 'dart:async';
import 'dart:math' as math;

import 'app_error.dart';

/// Policy expressed by callers of [withRetry]. Sealed so adding a new retry
/// shape forces every dispatcher (currently `withRetry`) to handle it.
sealed class RetryStrategy {
  const RetryStrategy();

  /// Retry forever, until the task succeeds or the predicate gives up.
  const factory RetryStrategy.indefinite() = _Indefinite;

  /// Retry at most [maxAttempts] times *in total* (initial call counts as the
  /// first attempt). Throws [ArgumentError] when [maxAttempts] is less than 1.
  factory RetryStrategy.bounded(int maxAttempts) = _Bounded;

  /// Do not retry; the task runs at most once.
  const factory RetryStrategy.none() = _None;
}

final class _Indefinite extends RetryStrategy {
  const _Indefinite();
}

final class _Bounded extends RetryStrategy {
  _Bounded(this.maxAttempts) {
    if (maxAttempts < 1) {
      throw ArgumentError.value(
        maxAttempts,
        'maxAttempts',
        'must be >= 1',
      );
    }
  }
  final int maxAttempts;
}

final class _None extends RetryStrategy {
  const _None();
}

/// Default predicate: retry when the failure is one of the three transient
/// network-shaped [AppError] variants. Anything else (including non-`AppError`
/// throwables) is left to bubble up to the caller.
bool defaultShouldRetry(Object error) {
  return error is RateLimitError ||
      error is UpstreamUnavailableError ||
      error is NetworkUnreachableError;
}

/// Hook used by [withRetry] to perform the inter-attempt wait. Tests inject
/// a `FakeAsync`-aware sleeper here so they can assert exact wait amounts
/// without actually pausing.
@pragma('vm:prefer-inline')
Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

/// Source of randomness for the jitter step. Injectable so tests get
/// deterministic delays.
final _defaultRng = math.Random();

/// Execute [task], honouring [strategy] on failure. The first attempt runs
/// immediately; subsequent attempts wait `initialDelay * 2^(n-1)` clamped to
/// [maxDelay], with a uniform jitter of `±(jitter * delay)`.
///
/// `RateLimitError.retryAfter` short-circuits the calculation: when present
/// it is used verbatim and jitter is not applied.
///
/// [shouldRetry] defaults to [defaultShouldRetry].
///
/// Throws [ArgumentError] when [jitter] is negative.
Future<T> withRetry<T>(
  Future<T> Function() task,
  RetryStrategy strategy, {
  Duration initialDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(minutes: 5),
  double jitter = 0.2,
  bool Function(Object error)? shouldRetry,
  Future<void> Function(Duration)? sleep,
  math.Random? random,
}) async {
  if (jitter < 0) {
    throw ArgumentError.value(jitter, 'jitter', 'must be non-negative');
  }
  final predicate = shouldRetry ?? defaultShouldRetry;
  final waiter = sleep ?? _defaultSleep;
  final rng = random ?? _defaultRng;

  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await task();
    } catch (error, stack) {
      final canRetryByPolicy = switch (strategy) {
        _None() => false,
        _Bounded(:final maxAttempts) => attempt < maxAttempts,
        _Indefinite() => true,
      };
      if (!canRetryByPolicy || !predicate(error)) {
        // Re-raise the original error, preserving the stack trace.
        Error.throwWithStackTrace(error, stack);
      }
      final delay = _computeDelay(
        attempt: attempt,
        initialDelay: initialDelay,
        maxDelay: maxDelay,
        jitter: jitter,
        error: error,
        rng: rng,
      );
      if (delay > Duration.zero) {
        await waiter(delay);
      }
    }
  }
}

/// Compute the wait before the next attempt (1-indexed: `attempt == 1` after
/// the first failure, etc.). Honours `RateLimitError.retryAfter`, clamps to
/// `maxDelay`, then applies `±jitter * delay`.
Duration _computeDelay({
  required int attempt,
  required Duration initialDelay,
  required Duration maxDelay,
  required double jitter,
  required Object error,
  required math.Random rng,
}) {
  if (error is RateLimitError && error.retryAfter != null) {
    // Server told us how long to wait; honour it verbatim, no jitter.
    return error.retryAfter!;
  }
  // Exponential backoff: initialDelay * 2^(attempt - 1).
  final exponent = attempt - 1;
  // Guard against overflow by computing in microseconds and capping.
  final maxMicros = maxDelay.inMicroseconds;
  final raw = initialDelay.inMicroseconds * _pow2Capped(exponent, maxMicros);
  final clamped = raw > maxMicros ? maxMicros : raw;
  // Apply jitter: uniform in [-jitter, +jitter].
  if (jitter == 0) {
    return Duration(microseconds: clamped);
  }
  final jitterFactor = (rng.nextDouble() * 2 - 1) * jitter; // [-jitter, +jitter]
  final adjusted = clamped + (clamped * jitterFactor).round();
  return Duration(microseconds: adjusted < 0 ? 0 : adjusted);
}

/// Compute `2^exponent` clamped against [cap] to avoid integer overflow on
/// long-running retries. We only need values up to `cap / initialDelay`, so
/// once the multiplier exceeds `cap` we can stop doubling.
int _pow2Capped(int exponent, int cap) {
  if (exponent <= 0) return 1;
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    if (result > cap) return result;
    result <<= 1;
  }
  return result;
}
