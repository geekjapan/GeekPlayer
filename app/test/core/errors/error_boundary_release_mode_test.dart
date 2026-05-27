import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/error_boundary.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

void main() {
  setUp(ErrorBoundary.resetForTesting);
  tearDown(() {
    debugIsReleaseModeOverride = null;
    ErrorBoundary.resetForTesting();
  });

  testWidgets(
    'release-mode builder produces the localized restart fallback',
    (tester) async {
      debugIsReleaseModeOverride = true;
      // Invoke the builder directly without installing it as the global
      // ErrorWidget.builder; flutter_test's _verifyErrorWidgetBuilderUnset
      // would otherwise fail before the tearDown reset runs.
      final widget = ErrorBoundary.buildErrorWidget(
        FlutterErrorDetails(
          exception: Exception('boom'),
          stack: StackTrace.current,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: widget,
        ),
      );

      expect(find.text('アプリを再起動してください'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    },
  );

  testWidgets(
    'debug-mode delegates to the previously installed builder',
    (tester) async {
      debugIsReleaseModeOverride = false;
      // ErrorBoundary captures whatever builder is active *at install time*.
      // In tests, that is the flutter_test default; the spec just requires
      // the release fallback to NOT appear in debug.
      final widget = ErrorBoundary.buildErrorWidget(
        FlutterErrorDetails(
          exception: Exception('x'),
          stack: StackTrace.current,
        ),
      );
      // In debug mode we must not produce the localized "アプリを再起動して
      // ください" prompt.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: widget,
        ),
      );
      expect(find.text('アプリを再起動してください'), findsNothing);
    },
  );
}
