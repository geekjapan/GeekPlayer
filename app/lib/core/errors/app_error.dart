/// Common error domain for GeekPlayer.
///
/// All errors crossing a layer boundary (network / storage / media / novel /
/// feature UI) MUST be either an [AppError] subtype, or be wrapped in
/// [UnknownError] before they reach a UI consumer or the structured logger.
///
/// See `openspec/changes/add-error-ux-infra/design.md` for the rationale
/// behind the variant catalog and the value-equality contract.
library;

import 'package:flutter/foundation.dart';

/// Sealed root of the GeekPlayer error hierarchy.
///
/// Implementing [Exception] keeps `throw appError` idiomatic. The `sealed`
/// modifier forces every consumer to handle the variants exhaustively via
/// `switch`, so adding a new variant produces compile-time errors at every
/// call site that maps errors to UI / logging.
@immutable
sealed class AppError implements Exception {
  const AppError(this.message, {this.cause, this.stackTrace});

  /// Human-readable description. Used as a fallback when no localization is
  /// available (e.g. detached `BuildContext`).
  final String message;

  /// The original throwable that caused this error, if any. Excluded from
  /// equality so that wrapping the same logical failure twice still compares
  /// equal.
  final Object? cause;

  /// Stack trace captured at the original throw site, if available. Excluded
  /// from equality for the same reason as [cause].
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType($message)');
    if (cause != null) {
      buffer.write(' caused by $cause');
    }
    return buffer.toString();
  }
}

/// Network call could not reach the host (DNS failure, offline, timeout).
final class NetworkUnreachableError extends AppError {
  const NetworkUnreachableError({
    required String message,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetworkUnreachableError && other.message == message);

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

/// Upstream signalled rate limiting (HTTP 429 or equivalent).
///
/// [retryAfter] reflects an explicit `Retry-After` directive when present.
/// `withRetry` honours it verbatim, bypassing the exponential backoff
/// calculation.
final class RateLimitError extends AppError {
  const RateLimitError({
    required String message,
    this.retryAfter,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RateLimitError &&
          other.message == message &&
          other.retryAfter == retryAfter);

  @override
  int get hashCode => Object.hash(runtimeType, message, retryAfter);
}

/// User has not granted (or has revoked) consent for the given [site].
///
/// [site] uses the short identifier convention from CONTEXT.md (e.g.
/// `'kakuyomu'`, `'narou'`, `'noc'`). Kept as a [String] rather than an enum
/// to avoid coupling `core/errors/` to `core/novel/`.
final class SiteConsentRequiredError extends AppError {
  const SiteConsentRequiredError({
    required String message,
    required this.site,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final String site;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteConsentRequiredError &&
          other.message == message &&
          other.site == site);

  @override
  int get hashCode => Object.hash(runtimeType, message, site);
}

/// `robots.txt` forbade fetching [path] on the target site.
final class RobotsDisallowedError extends AppError {
  const RobotsDisallowedError({
    required String message,
    required this.path,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RobotsDisallowedError &&
          other.message == message &&
          other.path == path);

  @override
  int get hashCode => Object.hash(runtimeType, message, path);
}

/// HTML parser could not extract the expected fields. [sourceUrl] points to
/// the offending document when available, to aid log-driven diagnosis.
final class HtmlParseError extends AppError {
  const HtmlParseError({
    required String message,
    this.sourceUrl,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final String? sourceUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HtmlParseError &&
          other.message == message &&
          other.sourceUrl == sourceUrl);

  @override
  int get hashCode => Object.hash(runtimeType, message, sourceUrl);
}

/// A referenced local file / URI is no longer reachable.
final class FileNotFoundError extends AppError {
  const FileNotFoundError({
    required String message,
    required this.uri,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final Uri uri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileNotFoundError &&
          other.message == message &&
          other.uri == uri);

  @override
  int get hashCode => Object.hash(runtimeType, message, uri);
}

/// The media format is recognised but not supported by the active engine.
/// [extension] is the file extension (without the leading dot) when known.
final class UnsupportedFormatError extends AppError {
  const UnsupportedFormatError({
    required String message,
    this.extension,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final String? extension;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnsupportedFormatError &&
          other.message == message &&
          other.extension == extension);

  @override
  int get hashCode => Object.hash(runtimeType, message, extension);
}

/// An upstream service is unreachable or returned 5xx. [statusCode] carries
/// the HTTP status when one was received; null indicates a transport-level
/// failure that never reached the response stage.
final class UpstreamUnavailableError extends AppError {
  const UpstreamUnavailableError({
    required String message,
    this.statusCode,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final int? statusCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpstreamUnavailableError &&
          other.message == message &&
          other.statusCode == statusCode);

  @override
  int get hashCode => Object.hash(runtimeType, message, statusCode);
}

/// Local storage (drift DB, cache files) ran out of room. [requestedBytes]
/// records the size of the failed write when the caller knows it.
final class StorageQuotaError extends AppError {
  const StorageQuotaError({
    required String message,
    this.requestedBytes,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause: cause, stackTrace: stackTrace);

  final int? requestedBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageQuotaError &&
          other.message == message &&
          other.requestedBytes == requestedBytes);

  @override
  int get hashCode => Object.hash(runtimeType, message, requestedBytes);
}

/// Fallback wrapper around an arbitrary throwable. Use sparingly: prefer a
/// more specific variant whenever the source error maps to one.
///
/// The single positional [original] argument captures both `message` (via
/// `toString()`) and `cause`, matching the spec contract.
final class UnknownError extends AppError {
  UnknownError(Object original, {StackTrace? stackTrace})
    : _original = original,
      super(original.toString(), cause: original, stackTrace: stackTrace);

  final Object _original;

  /// Convenience accessor for the underlying [cause] without losing its
  /// runtime type.
  Object get original => _original;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnknownError && other.message == message);

  @override
  int get hashCode => Object.hash(runtimeType, message);
}
