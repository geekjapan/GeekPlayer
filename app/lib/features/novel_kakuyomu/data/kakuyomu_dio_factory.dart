import 'package:dio/dio.dart';

import '../../../core/network/rate_limiter.dart';
import '../../../core/network/robots_txt.dart';
import '../../../core/network/site_dio.dart';
import '../../../core/novel/models/site.dart';

/// Kakuyomu-tuned rate limiter parameters per ADR-0001 §取得方針-3:
///   - 1 request / 2 seconds = 0.5 req/sec
///   - burst 1
///   - concurrency 1
RateLimiter buildKakuyomuRateLimiter({DateTime Function()? now}) {
  return RateLimiter(rate: 0.5, burst: 1, maxConcurrency: 1, now: now);
}

/// Build the Kakuyomu-specific [Dio] with the responsible-fetching
/// interceptor stack (robots → rate-limit → backoff → logging).
///
/// Per ADR-0001 the User-Agent is
/// `GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)`.
Dio buildKakuyomuDio({
  required String appVersion,
  required RateLimiter limiter,
  required RobotsCache robotsCache,
}) {
  return buildSiteDio(
    site: Site.kakuyomu,
    appVersion: appVersion,
    limiter: limiter,
    robotsCache: robotsCache,
  );
}
