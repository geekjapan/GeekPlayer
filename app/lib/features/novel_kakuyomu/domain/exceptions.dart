/// Site-specific exceptions raised by the Kakuyomu sources and
/// repository.
///
/// These compose with the cross-site hierarchies in
/// `core/network/errors.dart` (transport-level) and
/// `core/novel/errors.dart` (domain-level). Adapters at the source
/// boundary translate raw `DioException` / parser errors into one of
/// these so the UI can branch on a stable Kakuyomu-specific type.
library;

import '../../../core/network/errors.dart' as net;
import '../../../core/novel/errors.dart';

/// User has not granted (or has revoked) consent for the Kakuyomu site.
/// MUST be raised synchronously before any HTTP request is dispatched.
///
/// This type intentionally aliases the cross-site
/// [SiteConsentRequiredError] subclass — the Kakuyomu spec mentions
/// `SiteConsentDeniedException` as a Japanese-flavoured name, but we
/// keep the existing sealed hierarchy so generic UI handlers still
/// match.
typedef SiteConsentDeniedException = SiteConsentRequiredError;

/// HTML structure no longer matches `KakuyomuHtmlParser`'s expectations.
/// The reader screen should react with a [parser_failure_fallback]
/// panel rather than crashing.
final class KakuyomuParseException implements Exception {
  KakuyomuParseException({
    required this.message,
    required this.selector,
    this.url,
  });

  /// Free-form human-readable diagnostic.
  final String message;

  /// CSS selector path that was being matched when parsing failed.
  /// Surfaced verbatim in the "詳細をコピー" diagnostic blob.
  final String selector;

  /// Request URL whose response could not be parsed.
  final String? url;

  @override
  String toString() => 'KakuyomuParseException($selector @ $url): $message';
}

/// 404 from an episode page. Surfaces a friendlier UI state than the
/// raw `DioException`.
final class KakuyomuEpisodeNotFoundException implements Exception {
  KakuyomuEpisodeNotFoundException({
    required this.workId,
    required this.episodeId,
  });

  /// Kakuyomu work id (numeric string).
  final String workId;

  /// Kakuyomu episode id (numeric string).
  final String episodeId;

  @override
  String toString() =>
      'KakuyomuEpisodeNotFoundException(workId=$workId, episodeId=$episodeId)';
}

/// All retry budgets exhausted (typically 6 consecutive 429/503).
final class KakuyomuUpstreamUnavailableException implements Exception {
  KakuyomuUpstreamUnavailableException({
    required this.message,
    this.lastStatus,
  });

  final String message;
  final int? lastStatus;

  @override
  String toString() =>
      'KakuyomuUpstreamUnavailableException(status=$lastStatus): $message';
}

/// Target path is forbidden by `robots.txt`. Alias of the
/// transport-layer [net.RobotsDisallowedError] so Kakuyomu code can
/// `catch (RobotsDisallowedException)` symmetrically with the other
/// Kakuyomu-named exceptions.
typedef RobotsDisallowedException = net.RobotsDisallowedError;
