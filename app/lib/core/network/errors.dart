/// Sealed hierarchy of recoverable / fatal errors raised by the
/// `core/network` layer.
///
/// Defined separately from `core/novel/errors.dart` because these errors
/// arise from transport-level concerns (robots.txt, rate limit, network
/// unreachable) and apply to any caller, not just the novel feature.
/// Site-specific `NovelRepositoryError` subclasses (in `core/novel/`) may
/// wrap these as `cause`.
library;

/// Base sealed class for all network-layer errors.
sealed class NetworkError implements Exception {
  const NetworkError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The target path is disallowed by the host's `robots.txt`. The request
/// MUST NOT be dispatched. Also raised when `robots.txt` itself failed to
/// fetch (fail-closed; see `responsible-fetching` spec Scenario).
final class RobotsDisallowedError extends NetworkError {
  const RobotsDisallowedError(super.message, {this.host, this.path});

  /// Host whose robots.txt applied. Useful for diagnostic logging.
  final String? host;

  /// Path that was rejected (relative to host root).
  final String? path;
}

/// All retry budgets exhausted (typically 6 consecutive 429s). The caller
/// is expected to surface a friendly message and either let the user
/// retry later or back off the feature.
final class RateLimitExceededError extends NetworkError {
  const RateLimitExceededError(super.message, {this.lastStatus});

  final int? lastStatus;
}

/// DNS / socket level failure. Distinct from HTTP errors so the UI can
/// suggest "check your connection" instead of "try again later".
final class NetworkUnreachableError extends NetworkError {
  const NetworkUnreachableError(super.message, {this.cause});

  final Object? cause;
}
