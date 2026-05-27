import 'package:dio/dio.dart';

import '../novel/models/site.dart';
import 'interceptors/backoff_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/rate_limit_interceptor.dart';
import 'interceptors/robots_txt_interceptor.dart';
import 'rate_limiter.dart';
import 'robots_txt.dart';
import 'user_agent.dart';

/// Build a per-[Site] [Dio] instance pre-wired with the responsible
/// fetching stack.
///
/// Interceptor ordering (`responsible-fetching` Requirement
/// "Interceptor ordering"):
///   `RobotsTxtInterceptor` → `RateLimitInterceptor` →
///   `BackoffInterceptor` → `LoggingInterceptor`.
///
/// Why per-site: each site has its own [RateLimiter] profile (e.g.
/// kakuyomu is much stricter), and using a separate [Dio] makes the
/// dependency graph explicit (`Site → Dio`).
Dio buildSiteDio({
  required Site site,
  required String appVersion,
  required RateLimiter limiter,
  required RobotsCache robotsCache,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: site.baseUrl.toString(),
      headers: <String, dynamic>{kUserAgentHeader: buildUserAgent(appVersion)},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.addAll(<Interceptor>[
    RobotsTxtInterceptor(robotsCache),
    RateLimitInterceptor(limiter),
    BackoffInterceptor(),
    LoggingInterceptor(),
  ]);
  return dio;
}
