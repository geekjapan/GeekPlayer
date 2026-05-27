import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_error.dart';
import 'error_banner.dart';
import 'error_messages.dart';
import 'scaffold_messenger_key.dart';

/// Auto-dismiss duration for SnackBars dispatched by [showErrorToast].
/// See `error-ux-widgets` spec, "SnackBar auto-dismisses after 4 seconds".
const Duration kErrorToastDuration = Duration(seconds: 4);

/// De-duplication window for [showErrorToast]. Identical errors fired inside
/// this window are suppressed to avoid spamming the user when an upstream
/// retries quickly.
const Duration kErrorToastDedupWindow = Duration(seconds: 1);

/// Enqueue a Material 3 SnackBar describing [error]. The SnackBar uses the
/// severity-driven colour scheme from [backgroundColorForSeverity] and
/// auto-dismisses after [kErrorToastDuration].
///
/// When [onRetry] is non-null, the SnackBar embeds a `SnackBarAction` whose
/// label is the localized retry string and whose callback invokes [onRetry].
///
/// Calls that arrive within [kErrorToastDedupWindow] of an identical previous
/// call (same `AppError` runtime type + `message`) are suppressed.
void showErrorToast(
  BuildContext context,
  AppError error, {
  VoidCallback? onRetry,
}) {
  // The Riverpod container is reached via [ProviderScope]; if none is
  // attached, we degrade gracefully by skipping dedup and using the
  // ScaffoldMessenger from `context`.
  final container = ProviderScope.containerOf(context, listen: false);
  final signature = ToastDedupSignature(
    type: error.runtimeType,
    message: error.message,
  );
  final dedup = container.read(toastDedupRegistryProvider.notifier);
  if (dedup.shouldSuppress(signature, window: kErrorToastDedupWindow)) {
    return;
  }

  final messenger = _resolveMessenger(context, container);
  if (messenger == null) {
    // No ScaffoldMessenger is reachable — nothing we can do; the structured
    // logger has already recorded the error elsewhere.
    return;
  }

  final theme = Theme.of(context);
  final severity = severityOf(error);
  final background = backgroundColorForSeverity(severity, theme.colorScheme);
  final foreground = foregroundColorForSeverity(severity, theme.colorScheme);
  final message = ErrorMessages.localize(error, context);

  messenger.showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: foreground)),
      backgroundColor: background,
      duration: kErrorToastDuration,
      behavior: SnackBarBehavior.floating,
      action: onRetry == null
          ? null
          : SnackBarAction(
              label: ErrorMessages.actionRetry(context),
              textColor: foreground,
              onPressed: onRetry,
            ),
    ),
  );
}

/// Prefer the global key from [scaffoldMessengerKeyProvider]; fall back to
/// the ambient [ScaffoldMessenger.maybeOf] when the key is not attached
/// (e.g. inside widget tests that build a bare `MaterialApp`).
ScaffoldMessengerState? _resolveMessenger(
  BuildContext context,
  ProviderContainer container,
) {
  final key = container.read(scaffoldMessengerKeyProvider);
  final messenger = key.currentState;
  if (messenger != null) {
    return messenger;
  }
  return ScaffoldMessenger.maybeOf(context);
}
