import 'package:dio/dio.dart';

import '../errors.dart';
import '../robots_txt.dart';

/// Dio interceptor that rejects requests disallowed by `robots.txt`.
///
/// Ordering: this MUST run BEFORE rate limiting so a denied path does
/// not consume a token (`responsible-fetching` Requirement: Interceptor
/// ordering, Scenario "Disallowed path does not consume a rate token").
class RobotsTxtInterceptor extends Interceptor {
  RobotsTxtInterceptor(this._cache);

  final RobotsCache _cache;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Resolve final URI (Dio merges baseUrl + path here).
    final Uri uri = options.uri;
    // Skip robots.txt itself.
    if (uri.path == '/robots.txt') {
      handler.next(options);
      return;
    }
    try {
      await _cache.assertAllowed(uri.host, uri.path);
      handler.next(options);
    } on RobotsDisallowedError catch (err) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: err,
          message: err.message,
        ),
        true,
      );
    }
  }
}
