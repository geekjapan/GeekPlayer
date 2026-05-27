import 'package:dio/dio.dart';

import '../rate_limiter.dart';

/// Dio interceptor that gates each request through a [RateLimiter].
///
/// Because Dio's interceptor chain is per-event (request / response /
/// error) we cannot wrap a single `RateLimiter.run` call around the
/// whole flow. Instead, the request side calls
/// [RateLimiter.acquirePermit] to grab a token + concurrency slot, and
/// stashes the release callback in `RequestOptions.extra`. The release
/// happens in `onResponse` / `onError` — even when a [BackoffInterceptor]
/// retries inside the same logical request, the slot is held until the
/// final outcome (matching `responsible-fetching` spec "Backoff wait
/// holds the rate-limit slot").
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this._limiter);

  final RateLimiter _limiter;

  /// Extras key for the release callback.
  static const String _releaseKey = 'geekplayer.rateLimit.release';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final void Function() release = await _limiter.acquirePermit();
    options.extra[_releaseKey] = release;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _release(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _release(err.requestOptions);
    handler.next(err);
  }

  void _release(RequestOptions options) {
    final Object? release = options.extra.remove(_releaseKey);
    if (release is void Function()) release();
  }
}
