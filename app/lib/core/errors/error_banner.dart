import 'package:flutter/material.dart';

import 'app_error.dart';
import 'error_messages.dart';

/// Severity classification for an [AppError]. Drives both the SnackBar /
/// banner colour and the logger level. See design.md D3.
enum ErrorSeverity { info, warning, error }

/// Maps each [AppError] variant to its [ErrorSeverity]. Implemented as an
/// exhaustive switch so adding a new variant produces an analyzer error here.
ErrorSeverity severityOf(AppError error) => switch (error) {
  // warning: the user can probably retry / wait their way out.
  RateLimitError() => ErrorSeverity.warning,
  SiteConsentRequiredError() => ErrorSeverity.warning,
  HtmlParseError() => ErrorSeverity.warning,
  NetworkUnreachableError() => ErrorSeverity.warning,
  UpstreamUnavailableError() => ErrorSeverity.warning,
  // error: there is no automatic recovery; the user has to act.
  RobotsDisallowedError() => ErrorSeverity.error,
  FileNotFoundError() => ErrorSeverity.error,
  UnsupportedFormatError() => ErrorSeverity.error,
  StorageQuotaError() => ErrorSeverity.error,
  UnknownError() => ErrorSeverity.error,
};

/// Resolves the background colour used by [ErrorBanner] / `showErrorToast`
/// for the given [severity], following the Material 3 colour-role pattern
/// laid out in design.md D3.
Color backgroundColorForSeverity(ErrorSeverity severity, ColorScheme scheme) =>
    switch (severity) {
      ErrorSeverity.error => scheme.errorContainer,
      ErrorSeverity.warning => scheme.tertiaryContainer,
      ErrorSeverity.info => scheme.surfaceContainerHighest,
    };

/// Resolves the foreground (text / icon) colour to pair with
/// [backgroundColorForSeverity].
Color foregroundColorForSeverity(ErrorSeverity severity, ColorScheme scheme) =>
    switch (severity) {
      ErrorSeverity.error => scheme.onErrorContainer,
      ErrorSeverity.warning => scheme.onTertiaryContainer,
      ErrorSeverity.info => scheme.onSurface,
    };

/// Icon used by [ErrorBanner] (and by the release-mode error fallback) for
/// the given [severity].
IconData iconForSeverity(ErrorSeverity severity) => switch (severity) {
  ErrorSeverity.error => Icons.error_outline,
  ErrorSeverity.warning => Icons.warning_amber,
  ErrorSeverity.info => Icons.info_outline,
};

/// Persistent error banner. Unlike `showErrorToast`, [ErrorBanner] does not
/// auto-dismiss; it stays in the tree until [onDismiss] is invoked or its
/// parent removes it.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    required this.error,
    this.onRetry,
    this.onDismiss,
    super.key,
  });

  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final severity = severityOf(error);
    final scheme = Theme.of(context).colorScheme;
    final background = backgroundColorForSeverity(severity, scheme);
    final foreground = foregroundColorForSeverity(severity, scheme);
    final icon = iconForSeverity(severity);
    final message = ErrorMessages.localize(error, context);

    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: foreground),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(_retryLabel(context)),
              ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, color: foreground),
                onPressed: onDismiss,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
          ],
        ),
      ),
    );
  }

  /// Localized "再試行" / fallback. Pulled here (instead of into
  /// [ErrorMessages]) because the action is severity-agnostic.
  String _retryLabel(BuildContext context) {
    return ErrorMessages.actionRetry(context);
  }
}
