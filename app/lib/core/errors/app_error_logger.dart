import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'app_error.dart';
import 'error_banner.dart' show ErrorSeverity, severityOf;

/// Structured-logging entry point for the error domain.
///
/// `AppErrorLogger.log(err)` routes to the singleton [Logger] instance,
/// translating the [ErrorSeverity] of the variant into a `logger` [Level] and
/// building a deterministic payload that includes every identifying field of
/// the variant (so downstream tooling can grep for `type=RateLimitError` and
/// see the `retryAfter`).
class AppErrorLogger {
  AppErrorLogger._();

  /// Lazily-initialised singleton. In release builds we drop the pretty
  /// formatting (it inflates log volume); in debug builds developers benefit
  /// from boxed, colourised output.
  static Logger _logger = _buildDefaultLogger();

  /// Test seam: replace the underlying [Logger]. The previous instance is
  /// returned so tests can restore it after the test runs.
  @visibleForTesting
  static Logger setLoggerForTesting(Logger logger) {
    final previous = _logger;
    _logger = logger;
    return previous;
  }

  static Logger _buildDefaultLogger() {
    final printer = kReleaseMode ? SimplePrinter() : PrettyPrinter();
    return Logger(printer: printer);
  }

  /// Emit [error] through the active [Logger]. Severity-to-level mapping:
  /// `error` -> `Logger.e`, `warning` -> `Logger.w`, `info` -> `Logger.i`.
  static void log(AppError error) {
    final payload = buildPayload(error);
    final severity = severityOf(error);
    switch (severity) {
      case ErrorSeverity.error:
        _logger.e(payload, error: error.cause, stackTrace: error.stackTrace);
      case ErrorSeverity.warning:
        _logger.w(payload, error: error.cause, stackTrace: error.stackTrace);
      case ErrorSeverity.info:
        _logger.i(payload, error: error.cause, stackTrace: error.stackTrace);
    }
  }

  /// Build the structured payload for [error]. Public for unit-testing the
  /// payload independently of the [Logger] sink.
  @visibleForTesting
  static Map<String, Object?> buildPayload(AppError error) {
    final payload = <String, Object?>{
      'type': error.runtimeType.toString(),
      'message': error.message,
    };
    switch (error) {
      case NetworkUnreachableError():
        break;
      case RateLimitError(:final retryAfter):
        if (retryAfter != null) {
          payload['retryAfter'] = '${retryAfter.inSeconds}s';
        }
      case SiteConsentRequiredError(:final site):
        payload['site'] = site;
      case RobotsDisallowedError(:final path):
        payload['path'] = path;
      case HtmlParseError(:final sourceUrl):
        if (sourceUrl != null) payload['sourceUrl'] = sourceUrl;
      case FileNotFoundError(:final uri):
        payload['uri'] = uri.toString();
      case UnsupportedFormatError(:final extension):
        if (extension != null) payload['extension'] = extension;
      case UpstreamUnavailableError(:final statusCode):
        if (statusCode != null) payload['statusCode'] = statusCode;
      case StorageQuotaError(:final requestedBytes):
        if (requestedBytes != null) {
          payload['requestedBytes'] = requestedBytes;
        }
      case UnknownError():
        break;
    }
    if (error.cause != null) {
      payload['cause'] = error.cause.toString();
    }
    if (error.stackTrace != null) {
      payload['stackTrace'] = error.stackTrace.toString();
    }
    return payload;
  }
}
