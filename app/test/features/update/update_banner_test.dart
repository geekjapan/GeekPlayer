import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/update/update_banner.dart';
import 'package:geekplayer/features/update/update_checker.dart';
import 'package:geekplayer/features/update/update_checker_provider.dart';
import 'package:geekplayer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ---------------------------------------------------------------------------
// Fake UpdateChecker
// ---------------------------------------------------------------------------

class FakeUpdateChecker implements UpdateChecker {
  FakeUpdateChecker(this._result);
  final UpdateResult _result;

  @override
  Future<UpdateResult> checkForUpdate(String currentVersion) async => _result;
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

Widget _harness(UpdateResult result) {
  return ProviderScope(
    overrides: [
      updateCheckerProvider.overrideWithValue(FakeUpdateChecker(result)),
    ],
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: UpdateBanner()),
    ),
  );
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'GeekPlayer',
      packageName: 'dev.geekjapan.geekplayer',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('shows banner when update is available', (tester) async {
    await tester.pumpWidget(
      _harness(
        const UpdateAvailable(
          latestVersion: '0.2.0',
          releaseUrl:
              'https://github.com/geekjapan/GeekPlayer/releases/tag/v0.2.0',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsOneWidget);
    expect(find.byKey(const Key('update-banner-download')), findsOneWidget);
    expect(find.byKey(const Key('update-banner-dismiss')), findsOneWidget);
    // Version string appears in the banner body.
    expect(find.textContaining('0.2.0'), findsWidgets);
  });

  testWidgets('shows nothing when up to date', (tester) async {
    await tester.pumpWidget(_harness(const UpToDate()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsNothing);
  });

  testWidgets('dismiss hides the banner', (tester) async {
    await tester.pumpWidget(
      _harness(
        const UpdateAvailable(
          latestVersion: '0.2.0',
          releaseUrl:
              'https://github.com/geekjapan/GeekPlayer/releases/tag/v0.2.0',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('update-banner-dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsNothing);
  });

  testWidgets('shows nothing when checker throws', (tester) async {
    final checker = _ThrowingUpdateChecker();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [updateCheckerProvider.overrideWithValue(checker)],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: UpdateBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsNothing);
  });
}

class _ThrowingUpdateChecker implements UpdateChecker {
  @override
  Future<UpdateResult> checkForUpdate(String currentVersion) async {
    throw Exception('network error');
  }
}
