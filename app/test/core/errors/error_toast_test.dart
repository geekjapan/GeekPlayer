import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/error_banner.dart';
import 'package:geekplayer/core/errors/error_toast.dart';
import 'package:geekplayer/core/errors/scaffold_messenger_key.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

import '_variants.dart';

/// Builds a test harness with a MaterialApp wired to the
/// `scaffoldMessengerKeyProvider` so [showErrorToast] can resolve the
/// messenger via the global key.
Widget _harness({required Widget child}) {
  return ProviderScope(
    child: Consumer(
      builder: (context, ref, _) {
        final messengerKey = ref.watch(scaffoldMessengerKeyProvider);
        return MaterialApp(
          scaffoldMessengerKey: messengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(body: child),
        );
      },
    ),
  );
}

void main() {
  group('showErrorToast enqueues a SnackBar for every variant', () {
    for (final error in allErrorVariants) {
      testWidgets('${error.runtimeType}', (tester) async {
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          _harness(
            child: Builder(
              key: captureKey,
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showErrorToast(context, error),
                  child: const Text('go'),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
      });
    }
  });

  testWidgets('warning severity uses tertiaryContainer background', (
    tester,
  ) async {
    late ColorScheme scheme;
    await tester.pumpWidget(
      _harness(
        child: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return ElevatedButton(
              onPressed: () => showErrorToast(
                context,
                const RateLimitError(message: 'rate'),
              ),
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.backgroundColor, scheme.tertiaryContainer);
    expect(snack.duration, kErrorToastDuration);
  });

  testWidgets('error severity uses errorContainer background', (tester) async {
    late ColorScheme scheme;
    await tester.pumpWidget(
      _harness(
        child: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return ElevatedButton(
              onPressed: () => showErrorToast(
                context,
                const RobotsDisallowedError(message: 'm', path: '/x'),
              ),
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.backgroundColor, scheme.errorContainer);
  });

  testWidgets('onRetry exposes a SnackBarAction that fires once', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      _harness(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showErrorToast(
                context,
                const UpstreamUnavailableError(message: 'm'),
                onRetry: () => retryCount++,
              ),
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byType(SnackBarAction), findsOneWidget);
    // The SnackBarAction widget renders its label inside an internal button.
    // Invoke the action's onPressed callback directly by reading the widget,
    // because hit-testing the floating SnackBar in a unit test is flaky.
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed();
    expect(retryCount, 1);
  });

  testWidgets('SnackBar contains the localized message', (tester) async {
    await tester.pumpWidget(
      _harness(
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showErrorToast(
                context,
                const RateLimitError(
                  message: 'raw',
                  retryAfter: Duration(seconds: 30),
                ),
              ),
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.textContaining('30'), findsOneWidget);
    expect(find.textContaining('秒'), findsOneWidget);
  });
}
