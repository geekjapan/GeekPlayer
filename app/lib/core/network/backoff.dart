import 'dart:async';
import 'dart:math' as math;

import 'errors.dart';

/// Outcome of a single attempt as evaluated by [withExponentialBackoff].
class BackoffAttempt<T> {
  const BackoffAttempt._({
    this.value,
    this.shouldRetry = false,
    this.retryAfter,
    this.statusCode,
  });

  /// Build a "succeeded — return [value]" outcome.
  factory BackoffAttempt.success(T value) =>
      BackoffAttempt<T>._(value: value);

  /// Build a "retry after [retryAfter] (or computed wait)" outcome.
  /// Used for 429 / 503 responses.
  factory BackoffAttempt.retry({
    Duration? retryAfter,
    required int statusCode,
  }) {
    return BackoffAttempt<T>._(
      shouldRetry: true,
      retryAfter: retryAfter,
      statusCode: statusCode,
    );
  }

  /// Build a "give up, propagate as fatal" outcome.
  factory BackoffAttempt.fatal() => BackoffAttempt<T>._();

  final T? value;
  final bool shouldRetry;
  final Duration? retryAfter;
  final int? statusCode;
}

/// Retry policy used by [withExponentialBackoff]. Defaults match
/// ADR-0001 §取得方針-6 and ADR-0003 §取得方針-6:
///   - initial 1s, doubling each attempt
///   - capped at 5 minutes per wait
///   - up to 6 attempts (so total ≈ 1+2+4+8+16+32+... ≤ 5 min × 6)
///   - ±20% jitter (skipped when `Retry-After` is honored explicitly)
class RetryPolicy {
  const RetryPolicy({
    this.initialDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
    this.maxAttempts = 6,
    this.jitter = 0.2,
  });

  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;
  final int maxAttempts;

  /// Fractional jitter, e.g. `0.2` = ±20%.
  final double jitter;
}

/// Calculate the i-th wait (0-based) under [policy], excluding jitter
/// and Retry-After overrides. Exposed for tests.
Duration computeBackoffDelay(int attempt, RetryPolicy policy) {
  final double scaled = policy.initialDelay.inMilliseconds *
      math.pow(policy.multiplier, attempt).toDouble();
  final int clampedMs = scaled.isFinite
      ? scaled.clamp(0, policy.maxDelay.inMilliseconds.toDouble()).toInt()
      : policy.maxDelay.inMilliseconds;
  return Duration(milliseconds: clampedMs);
}

/// Apply jitter ±[fraction] (uniform) to [delay].
Duration applyJitter(Duration delay, double fraction, math.Random random) {
  if (fraction <= 0) return delay;
  final double low = 1.0 - fraction;
  final double high = 1.0 + fraction;
  final double factor = low + (high - low) * random.nextDouble();
  return Duration(
    microseconds: (delay.inMicroseconds * factor).round(),
  );
}

/// Drive [task] with exponential backoff on retryable outcomes.
///
/// [task] receives the 0-based attempt index and returns a
/// [BackoffAttempt] describing the result. The wrapper sleeps between
/// retries according to [policy], honoring a `Retry-After` value when
/// provided. On final failure throws [RateLimitExceededError].
Future<T> withExponentialBackoff<T>(
  Future<BackoffAttempt<T>> Function(int attempt) task, {
  RetryPolicy policy = const RetryPolicy(),
  math.Random? random,
  Future<void> Function(Duration)? sleep,
}) async {
  final math.Random rng = random ?? math.Random();
  final Future<void> Function(Duration) doSleep =
      sleep ?? (Duration d) => Future<void>.delayed(d);
  int? lastStatus;

  for (int attempt = 0; attempt < policy.maxAttempts; attempt++) {
    final BackoffAttempt<T> outcome = await task(attempt);
    if (!outcome.shouldRetry && outcome.value is T) {
      return outcome.value as T;
    }
    if (!outcome.shouldRetry) {
      // Fatal non-retry. Propagate using the success-or-throw model is
      // the caller's responsibility — they should throw inside [task]
      // for non-retry errors. We treat fatal-no-value as fatal.
      throw const RateLimitExceededError(
        'withExponentialBackoff: task returned fatal without retry',
      );
    }
    lastStatus = outcome.statusCode;
    if (attempt == policy.maxAttempts - 1) break;
    final Duration wait;
    if (outcome.retryAfter != null) {
      // Retry-After is explicit; do NOT jitter.
      wait = outcome.retryAfter!;
    } else {
      final Duration base = computeBackoffDelay(attempt, policy);
      wait = applyJitter(base, policy.jitter, rng);
    }
    await doSleep(wait);
  }

  throw RateLimitExceededError(
    'Retries exhausted after ${policy.maxAttempts} attempts',
    lastStatus: lastStatus,
  );
}
