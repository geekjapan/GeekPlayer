import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/error_boundary.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

void main() {
  tearDown(() {
    debugIsReleaseModeOverride = null;
    ErrorBoundary.resetForTesting();
  });

  test('install() is idempotent — repeated calls leave latch true', () {
    expect(ErrorBoundary.isInstalled, isFalse);
    ErrorBoundary.install();
    expect(ErrorBoundary.isInstalled, isTrue);
    ErrorBoundary.install();
    ErrorBoundary.install();
    expect(ErrorBoundary.isInstalled, isTrue);
  });

  testWidgets(
    'buildErrorWidget never produces nested release fallbacks',
    (tester) async {
      debugIsReleaseModeOverride = true;
      // Call the function directly; do not touch ErrorWidget.builder so the
      // flutter_test binding's "builder unchanged" invariant is preserved.
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
      // Exactly one localized prompt + one icon — never doubled.
      expect(find.text('アプリを再起動してください'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    },
  );
}
