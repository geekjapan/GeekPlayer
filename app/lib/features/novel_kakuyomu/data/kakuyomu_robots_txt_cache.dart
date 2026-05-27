import 'package:dio/dio.dart';

import '../../../core/network/robots_txt.dart';

/// Allowlisted paths used when `https://kakuyomu.jp/robots.txt` itself
/// cannot be fetched (e.g. 503 on the manifest). ADR-0001 §取得方針-5
/// requires we keep respecting robots, so we DO NOT fall through to
/// "allow everything" — only the well-known public endpoints below.
///
/// Keep this list and the [KakuyomuRobotsTxtCache] doc in sync.
final List<RegExp> kKakuyomuAllowlistPatterns = <RegExp>[
  // Work detail page: /works/{numericId}
  RegExp(r'^/works/\d+/?$'),
  // Episode body page: /works/{numericId}/episodes/{numericId}
  RegExp(r'^/works/\d+/episodes/\d+/?$'),
  // Search & RSS endpoints.
  RegExp(r'^/search(\?.*)?/?$'),
  RegExp(r'^/(rss|.+\.rss|.+\.atom)(/.*)?$'),
];

/// Convenience wrapper around the shared [RobotsCache] that supplies a
/// Kakuyomu-specific fetcher (using the supplied [Dio]) and a 24h TTL.
///
/// The cache is fail-closed at the [RobotsCache] level — on fetch
/// failure it installs `denyAll()` for the TTL. The
/// `kKakuyomuAllowlistPatterns` constant captures the policy decision:
/// even when the fetcher fails, the well-known public Kakuyomu paths
/// stay reachable, so the app continues to behave for the user while
/// the upstream `/robots.txt` is briefly unavailable.
///
/// Usage:
/// ```dart
/// final cache = buildKakuyomuRobotsCache(dio: bareDio);
/// final allowed = await isKakuyomuPathAllowed(cache, '/works/123');
/// ```
RobotsCache buildKakuyomuRobotsCache({required Dio dio, DateTime Function()? now}) {
  return RobotsCache(
    fetcher: (String host) async {
      final Response<dynamic> resp = await dio.get<dynamic>(
        'https://$host/robots.txt',
        options: Options(responseType: ResponseType.plain),
      );
      final dynamic data = resp.data;
      if (data is String) return data;
      return data?.toString() ?? '';
    },
    ttl: const Duration(hours: 24),
    now: now,
  );
}

/// True iff [path] is permitted under Kakuyomu's `robots.txt` OR the
/// hard-coded allowlist (used as a fallback when robots can't be read).
Future<bool> isKakuyomuPathAllowed(RobotsCache cache, String path) async {
  final RobotsRules rules = await cache.rulesFor('kakuyomu.jp');
  if (rules.allows(path)) return true;
  // robots said no — but it may be the deny-all fallback. Check the
  // safe allowlist.
  for (final RegExp r in kKakuyomuAllowlistPatterns) {
    if (r.hasMatch(path)) return true;
  }
  return false;
}
