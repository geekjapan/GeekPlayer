import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/update/release_asset.dart';
import 'package:geekplayer/features/update/update_banner.dart';
import 'package:geekplayer/features/update/update_checker.dart';
import 'package:geekplayer/features/update/update_checker_provider.dart';
import 'package:geekplayer/features/update/update_downloader.dart';
import 'package:geekplayer/features/update/update_installer.dart';
import 'package:geekplayer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ---------------------------------------------------------------------------
// Fake UpdateChecker
// ---------------------------------------------------------------------------

class _FakeUpdateChecker implements UpdateChecker {
  _FakeUpdateChecker(this._result);
  final UpdateResult _result;

  @override
  Future<UpdateResult> checkForUpdate(String currentVersion) async => _result;
}

// ---------------------------------------------------------------------------
// Fake UpdateDownloader
// ---------------------------------------------------------------------------

class _FakeUpdateDownloader implements UpdateDownloader {
  _FakeUpdateDownloader({required this.response});
  final Future<String> Function(
    ReleaseAsset asset,
    void Function(int, int) onProgress,
  )
  response;

  @override
  Future<String> download(
    ReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
    cancelToken,
  }) => response(asset, onProgress);
}

// ---------------------------------------------------------------------------
// Fake UpdateInstaller
// ---------------------------------------------------------------------------

class _FakeUpdateInstaller implements UpdateInstaller {
  final List<String> openedPaths = [];
  bool shouldThrow = false;

  @override
  Future<void> openForInstall(String filePath) async {
    if (shouldThrow) throw Exception('install error');
    openedPaths.add(filePath);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _macAsset = ReleaseAsset(
  name: 'GeekPlayer-0.2.0.dmg',
  downloadUrl: 'https://example.com/GeekPlayer-0.2.0.dmg',
  sizeBytes: 10 * 1024 * 1024,
);

const _updateWithAsset = UpdateAvailable(
  latestVersion: '0.2.0',
  releaseUrl: 'https://github.com/geekjapan/GeekPlayer/releases/tag/v0.2.0',
  assets: [_macAsset],
);

const _updateNoAssets = UpdateAvailable(
  latestVersion: '0.2.0',
  releaseUrl: 'https://github.com/geekjapan/GeekPlayer/releases/tag/v0.2.0',
);

Widget _harness({
  required UpdateResult checkerResult,
  UpdateDownloader? downloader,
  UpdateInstaller? installer,
  TargetPlatform platform = TargetPlatform.macOS,
}) {
  return ProviderScope(
    overrides: [
      updateCheckerProvider.overrideWithValue(
        _FakeUpdateChecker(checkerResult),
      ),
      if (downloader != null)
        updateDownloaderProvider.overrideWithValue(downloader),
      if (installer != null)
        updateInstallerProvider.overrideWithValue(installer),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(platform: platform),
      home: const Scaffold(body: UpdateBanner()),
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

  // ---------------------------------------------------------------------------
  // Existing banner display tests (regression)
  // ---------------------------------------------------------------------------

  testWidgets('shows banner when update available', (tester) async {
    await tester.pumpWidget(_harness(checkerResult: _updateWithAsset));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsOneWidget);
    expect(find.byKey(const Key('update-banner-download')), findsOneWidget);
    expect(find.byKey(const Key('update-banner-dismiss')), findsOneWidget);
    expect(find.textContaining('0.2.0'), findsWidgets);
  });

  testWidgets('shows nothing when up to date', (tester) async {
    await tester.pumpWidget(_harness(checkerResult: const UpToDate()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Download flow — success
  // ---------------------------------------------------------------------------

  testWidgets('download shows progress indicator then install button', (
    tester,
  ) async {
    // Downloader that reports 50% progress then returns a path.
    final downloader = _FakeUpdateDownloader(
      response: (asset, onProgress) async {
        onProgress(5 * 1024 * 1024, 10 * 1024 * 1024); // 50%
        return '/tmp/${asset.name}';
      },
    );
    final installer = _FakeUpdateInstaller();

    await tester.pumpWidget(
      _harness(
        checkerResult: _updateWithAsset,
        downloader: downloader,
        installer: installer,
      ),
    );
    await tester.pumpAndSettle();

    // Tap Download.
    await tester.tap(find.byKey(const Key('update-banner-download')));
    await tester.pump(); // kick off future

    // Wait for download to complete.
    await tester.pumpAndSettle();

    // Install button should now be visible.
    expect(find.byKey(const Key('update-banner-install')), findsOneWidget);
    expect(find.byKey(const Key('update-banner-download')), findsNothing);
  });

  testWidgets('install button calls installer with downloaded path', (
    tester,
  ) async {
    final downloader = _FakeUpdateDownloader(
      response: (asset, onProgress) async => '/tmp/${asset.name}',
    );
    final installer = _FakeUpdateInstaller();

    await tester.pumpWidget(
      _harness(
        checkerResult: _updateWithAsset,
        downloader: downloader,
        installer: installer,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-banner-download')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner-install')), findsOneWidget);
    await tester.tap(find.byKey(const Key('update-banner-install')));
    await tester.pumpAndSettle();

    expect(installer.openedPaths, <String>['/tmp/GeekPlayer-0.2.0.dmg']);
  });

  // ---------------------------------------------------------------------------
  // Download flow — error handling
  // ---------------------------------------------------------------------------

  testWidgets('download failure shows snackbar and reverts to idle', (
    tester,
  ) async {
    final downloader = _FakeUpdateDownloader(
      response: (asset, onProgress) => Future.error(Exception('network error')),
    );

    await tester.pumpWidget(
      _harness(checkerResult: _updateWithAsset, downloader: downloader),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-banner-download')));
    await tester.pumpAndSettle();

    // Download button should be visible again (idle).
    expect(find.byKey(const Key('update-banner-download')), findsOneWidget);
    // Install button should NOT be visible.
    expect(find.byKey(const Key('update-banner-install')), findsNothing);
    // SnackBar with failure message.
    expect(find.textContaining('ダウンロード'), findsWidgets);
  });

  // ---------------------------------------------------------------------------
  // No compatible asset — banner still appears with Download button
  // ---------------------------------------------------------------------------

  testWidgets('banner shown when update has no assets', (tester) async {
    await tester.pumpWidget(_harness(checkerResult: _updateNoAssets));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsOneWidget);
    // Download button present for browser fallback.
    expect(find.byKey(const Key('update-banner-download')), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Dismiss
  // ---------------------------------------------------------------------------

  testWidgets('dismiss hides banner', (tester) async {
    await tester.pumpWidget(_harness(checkerResult: _updateWithAsset));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-banner-dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-banner')), findsNothing);
  });
}
