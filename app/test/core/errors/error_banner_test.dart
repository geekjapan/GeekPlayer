import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/error_banner.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

import '_variants.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ErrorBanner renders for every variant', () {
    for (final error in allErrorVariants) {
      testWidgets('${error.runtimeType}', (tester) async {
        await tester.pumpWidget(_wrap(ErrorBanner(error: error)));
        expect(tester.takeException(), isNull);
        // The banner must render at least one non-empty text node.
        final texts = find.byType(Text);
        expect(texts, findsWidgets);
        final hasNonEmpty = tester
            .widgetList<Text>(texts)
            .any((t) => (t.data ?? '').isNotEmpty);
        expect(hasNonEmpty, isTrue);
      });
    }
  });

  testWidgets('error severity shows error_outline icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ErrorBanner(
          error: FileNotFoundError(message: 'm', uri: Uri.parse('file:///x')),
        ),
      ),
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('warning severity shows warning_amber icon', (tester) async {
    await tester.pumpWidget(
      _wrap(const ErrorBanner(error: RateLimitError(message: 'm'))),
    );
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('onRetry invokes the callback exactly once', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _wrap(
        ErrorBanner(
          error: const UpstreamUnavailableError(message: 'm'),
          onRetry: () => retries++,
        ),
      ),
    );
    expect(find.text('再試行'), findsOneWidget);
    await tester.tap(find.text('再試行'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('banner does not auto-dismiss', (tester) async {
    await tester.pumpWidget(
      _wrap(const ErrorBanner(error: RateLimitError(message: 'm'))),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(ErrorBanner), findsOneWidget);
  });

  testWidgets('onDismiss exposes a close button', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      _wrap(
        ErrorBanner(
          error: const NetworkUnreachableError(message: 'm'),
          onDismiss: () => dismissed++,
        ),
      ),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(dismissed, 1);
  });
}
