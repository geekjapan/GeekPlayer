import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'app_error.dart';

/// Maps an [AppError] variant to a user-facing localized string.
///
/// When `AppLocalizations.of(context)` is null — for example when the helper
/// is invoked from `ErrorWidget.builder` with a detached context — the
/// function falls back to [AppError.message] verbatim so the user still sees
/// _something_ instead of throwing a `NoSuchMethodError`.
class ErrorMessages {
  ErrorMessages._();

  /// Localized text for [error]. Honours [BuildContext]'s active locale.
  static String localize(AppError error, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return error.message;
    }
    return switch (error) {
      NetworkUnreachableError() => l10n.errorNetworkUnreachable,
      RateLimitError(:final retryAfter) => l10n.errorRateLimit(
        retryAfter?.inSeconds ?? 0,
      ),
      SiteConsentRequiredError(:final site) => l10n.errorSiteConsentRequired(
        site,
      ),
      RobotsDisallowedError() => l10n.errorRobotsDisallowed,
      HtmlParseError() => l10n.errorHtmlParse,
      FileNotFoundError() => l10n.errorFileNotFound,
      UnsupportedFormatError() => l10n.errorUnsupportedFormat,
      UpstreamUnavailableError() => l10n.errorUpstreamUnavailable,
      StorageQuotaError() => l10n.errorStorageQuota,
      UnknownError() => l10n.errorUnknown,
    };
  }

  /// Localized "再試行" label, falls back to a hard-coded ja string when no
  /// localizations are installed.
  static String actionRetry(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n?.actionRetry ?? '再試行';
  }

  /// Localized "アプリを再起動してください" label, with the same fallback contract
  /// as [actionRetry] so the release-mode crash screen can still render in
  /// degraded contexts.
  static String errorBoundaryRestartPrompt(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n?.errorBoundaryRestartPrompt ?? 'アプリを再起動してください';
  }
}
