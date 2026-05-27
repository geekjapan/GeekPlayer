import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../backoff.dart';
import '../errors.dart';

/// Dio interceptor implementing exponential backoff on 429 / 503.
///
/// Matches `responsible-fetching` Requirement "Exponential backoff on
/// 429 / 503" (ADR-0001 §取得方針-6, ADR-0003 §取得方針-6):
///
///   - initial 1s, doubling each attempt, capped at 5 minutes
///   - up to 6 total attempts
///   - `Retry-After` (when present and parseable) overrides the
///     calculated wait, with no jitter applied to that explicit value
///   - other 4xx / 5xx statuses fail immediately
///
/// On exhaustion, the original [DioException] is rewritten with
/// `error: RateLimitExceededError(...)` so callers can branch on the
/// concrete error type.
class BackoffInterceptor extends Interceptor {
  BackoffInterceptor({
    this.policy = const RetryPolicy(),
    math.Random? random,
    Future<void> Function(Duration)? sleep,
  }) : _random = random ?? math.Random(),
       _sleep = sleep ?? ((Duration d) => Future<void>.delayed(d));

  final RetryPolicy policy;
  final math.Random _random;
  final Future<void> Function(Duration) _sleep;

  /// Stash for the current attempt index keyed by RequestOptions identity.
  /// We use `extra` because each retry creates a fresh request flow but
  /// the original RequestOptions is reused by Dio.
  static const String _attemptKey = 'geekplayer.backoff.attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final int? status = err.response?.statusCode;
    if (status == null || (status != 429 && status != 503)) {
      handler.next(err);
      return;
    }
    final RequestOptions opts = err.requestOptions;
    final int attempt = (opts.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= policy.maxAttempts - 1) {
      // Out of budget.
      handler.next(
        err.copyWith(
          error: RateLimitExceededError(
            'Retries exhausted after ${policy.maxAttempts} attempts',
            lastStatus: status,
          ),
        ),
      );
      return;
    }

    final Duration? retryAfter = _parseRetryAfter(err.response?.headers);
    final Duration wait;
    if (retryAfter != null) {
      wait = retryAfter;
    } else {
      wait = applyJitter(
        computeBackoffDelay(attempt, policy),
        policy.jitter,
        _random,
      );
    }
    await _sleep(wait);

    opts.extra[_attemptKey] = attempt + 1;
    try {
      // Reissue the request via a fresh Dio instance derived from the
      // original. We rely on the existing connection's interceptors
      // running again. The Dio v5 idiomatic way to retry is to call
      // dio.fetch with the same options.
      final Dio dio = Dio(
        BaseOptions(
          baseUrl: opts.baseUrl,
          headers: opts.headers,
          connectTimeout: opts.connectTimeout,
          receiveTimeout: opts.receiveTimeout,
          sendTimeout: opts.sendTimeout,
          contentType: opts.contentType,
          responseType: opts.responseType,
          followRedirects: opts.followRedirects,
          validateStatus: opts.validateStatus,
        ),
      );
      final Response<dynamic> response = await dio.fetch<dynamic>(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      // Recurse through onError again — but Dio interceptors aren't
      // applied to dio.fetch from a fresh Dio; instead we manually call
      // ourselves to maintain the retry loop.
      await onError(e, handler);
    }
  }

  Duration? _parseRetryAfter(Headers? headers) {
    if (headers == null) return null;
    final String? value = headers.value('retry-after');
    if (value == null) return null;
    // Integer-seconds form. HTTP-date form is not implemented (rare in
    // practice for 429/503 from the sites we target).
    final int? seconds = int.tryParse(value.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}
