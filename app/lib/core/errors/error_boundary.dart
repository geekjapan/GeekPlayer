import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_error.dart';
import 'app_error_logger.dart';
import 'error_banner.dart';
import 'error_messages.dart';

/// Test seam: lets unit tests pretend they are in release mode without
/// shipping a separate release-mode test binary. Production callers leave
/// this `null` and the [ErrorBoundary] consults [kReleaseMode] directly.
@visibleForTesting
bool? debugIsReleaseModeOverride;

/// Whether `_ReleaseErrorFallback` should be installed. Honours the test
/// override when set; otherwise falls back to [kReleaseMode].
bool _isReleaseMode() => debugIsReleaseModeOverride ?? kReleaseMode;

void _flutterErrorHandler(FlutterErrorDetails details) {
  ErrorBoundary._handleFlutterError(details);
}

/// Installs an [ErrorWidget.builder] override and wires up
/// `runZonedGuarded` / `FlutterError.onError` so that uncaught errors flow
/// through [AppErrorLogger] instead of disappearing into the void.
class ErrorBoundary {
  ErrorBoundary._();

  static bool _isInstalled = false;
  static ErrorWidgetBuilder? _previousBuilder;
  static bool _isFlutterErrorHandlerInstalled = false;
  static FlutterExceptionHandler? _previousFlutterErrorHandler;

  /// Test-only view of the idempotency latch.
  @visibleForTesting
  static bool get isInstalled => _isInstalled;

  /// Replace [ErrorWidget.builder] with one that shows
  /// [_ReleaseErrorFallback] in release builds and delegates to the previous
  /// builder in debug builds. Idempotent: subsequent calls are no-ops, so
  /// repeated invocations cannot nest fallbacks on top of each other.
  static void install() {
    if (_isInstalled) {
      return;
    }
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = buildErrorWidget;
    _isInstalled = true;
  }

  /// The replacement builder that [install] wires into [ErrorWidget.builder].
  /// Exposed for unit tests that prefer to invoke the function directly
  /// rather than tamper with the global `ErrorWidget.builder` slot (which
  /// `flutter_test` resets between tests).
  @visibleForTesting
  static Widget buildErrorWidget(FlutterErrorDetails details) {
    if (_isReleaseMode()) {
      return _ReleaseErrorFallback(details: details);
    }
    final fallback = _previousBuilder ?? ErrorWidget.builder;
    return fallback(details);
  }

  static void installFlutterErrorHandler() {
    final currentHandler = FlutterError.onError;
    if (identical(currentHandler, _flutterErrorHandler)) {
      return;
    }
    _previousFlutterErrorHandler = currentHandler;
    FlutterError.onError = _flutterErrorHandler;
    _isFlutterErrorHandlerInstalled = true;
  }

  static void _handleFlutterError(FlutterErrorDetails details) {
    AppErrorLogger.log(
      UnknownError(details.exception, stackTrace: details.stack),
    );
    if (_previousFlutterErrorHandler != null) {
      _previousFlutterErrorHandler!(details);
    } else {
      FlutterError.presentError(details);
    }
  }

  /// Test-only escape hatch to restore the original [ErrorWidget.builder]
  /// and reset the idempotency latch between tests.
  @visibleForTesting
  static void resetForTesting() {
    if (_isInstalled && _previousBuilder != null) {
      ErrorWidget.builder = _previousBuilder!;
    }
    _previousBuilder = null;
    _isInstalled = false;

    if (_isFlutterErrorHandlerInstalled &&
        identical(FlutterError.onError, _flutterErrorHandler)) {
      FlutterError.onError = _previousFlutterErrorHandler;
    }
    _previousFlutterErrorHandler = null;
    _isFlutterErrorHandlerInstalled = false;
  }
}

/// Release-mode visual replacement for Flutter's default red error widget.
///
/// Visually matches [ErrorBanner] with `error` severity but adds a localized
/// "アプリを再起動してください" prompt. Logs the underlying failure exactly
/// once per instance lifetime so we never lose the trace in production.
class _ReleaseErrorFallback extends StatefulWidget {
  const _ReleaseErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  State<_ReleaseErrorFallback> createState() => _ReleaseErrorFallbackState();
}

class _ReleaseErrorFallbackState extends State<_ReleaseErrorFallback> {
  @override
  void initState() {
    super.initState();
    AppErrorLogger.log(
      UnknownError(widget.details.exception, stackTrace: widget.details.stack),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The fallback can be invoked outside a Material ancestor (for example
    // when `MaterialApp.builder` itself throws). Wrap defensively so we
    // always have a [Material] for the banner styling.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFFFFEBEE), // soft red — pre-theme safe fallback
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  ErrorMessages.errorBoundaryRestartPrompt(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs app startup in `runZonedGuarded` so that uncaught async errors land in
/// [AppErrorLogger] rather than the framework's default `print`. Also wires
/// up [FlutterError.onError] to log first and delegate to whatever handler
/// was previously installed.
///
/// The Flutter binding must be initialized in the same zone that later calls
/// [runApp], so callers that do async startup work before rendering should put
/// that work inside [body].
Future<void> runWithErrorBoundary(FutureOr<void> Function() body) async {
  final completer = Completer<void>();
  runZonedGuarded<void>(
    () {
      Future<void>.sync(() {
        WidgetsFlutterBinding.ensureInitialized();
        ErrorBoundary.install();
        ErrorBoundary.installFlutterErrorHandler();
        return body();
      }).then(
        (_) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (Object error, StackTrace stack) {
          AppErrorLogger.log(UnknownError(error, stackTrace: stack));
          if (!completer.isCompleted) {
            completer.completeError(error, stack);
          }
        },
      );
    },
    (error, stack) {
      AppErrorLogger.log(UnknownError(error, stackTrace: stack));
    },
  );
  await completer.future;
}

/// Wraps [runApp] in the standard GeekPlayer error boundary.
Future<void> runAppWithErrorBoundary(Widget app) async {
  await runWithErrorBoundary(() => runApp(app));
}
