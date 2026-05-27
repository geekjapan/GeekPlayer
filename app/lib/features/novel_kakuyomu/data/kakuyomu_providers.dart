import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/rate_limiter.dart';
import '../../../core/network/robots_txt.dart';
import 'kakuyomu_dio_factory.dart';
import 'kakuyomu_robots_txt_cache.dart';

part 'kakuyomu_providers.g.dart';

/// App semver string sourced from `package_info_plus`. Used to build
/// the canonical Kakuyomu User-Agent.
@Riverpod(keepAlive: true)
Future<String> kakuyomuAppVersion(Ref ref) async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  // Fall back to a sentinel only if the platform returns an empty
  // version (unit tests on bare Dart VM).
  return info.version.isEmpty ? '0.0.0' : info.version;
}

/// Kakuyomu-tuned [RateLimiter] (0.5 req/sec, burst 1, concurrency 1).
@Riverpod(keepAlive: true)
RateLimiter kakuyomuRateLimiter(Ref ref) => buildKakuyomuRateLimiter();

/// Bare Dio used solely to fetch `/robots.txt`. Does NOT go through
/// the interceptor stack (would deadlock — robots interceptor would
/// re-fetch). Has the proper User-Agent so the request is identifiable.
@Riverpod(keepAlive: true)
Future<Dio> kakuyomuRobotsDio(Ref ref) async {
  final String version = await ref.watch(kakuyomuAppVersionProvider.future);
  return Dio(
    BaseOptions(
      headers: <String, dynamic>{
        'User-Agent':
            'GeekPlayer/$version (+https://github.com/geekjapan/GeekPlayer; personal-use)',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}

/// Shared [RobotsCache] for `kakuyomu.jp` (24h TTL, fail-closed with
/// the kakuyomu allowlist fallback at the source layer).
@Riverpod(keepAlive: true)
Future<RobotsCache> kakuyomuRobotsCache(Ref ref) async {
  final Dio dio = await ref.watch(kakuyomuRobotsDioProvider.future);
  return buildKakuyomuRobotsCache(dio: dio);
}

/// The Kakuyomu-tuned [Dio] consumed by `KakuyomuRssSource` and
/// `KakuyomuHtmlSource`.
@Riverpod(keepAlive: true)
Future<Dio> kakuyomuDio(Ref ref) async {
  final String version = await ref.watch(kakuyomuAppVersionProvider.future);
  final RateLimiter limiter = ref.watch(kakuyomuRateLimiterProvider);
  final RobotsCache robots = await ref.watch(kakuyomuRobotsCacheProvider.future);
  return buildKakuyomuDio(
    appVersion: version,
    limiter: limiter,
    robotsCache: robots,
  );
}
