import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/about/presentation/about_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

Widget _harness() {
  return const ProviderScope(child: MaterialApp(home: AboutScreen()));
}

void main() {
  setUp(() {
    // Reset the mock between tests.
    PackageInfo.setMockInitialValues(
      appName: 'GeekPlayer',
      packageName: 'dev.geekjapan.geekplayer',
      version: '0.1.0',
      buildNumber: '12',
      buildSignature: '',
    );
  });

  testWidgets('renders app name, version, build number, and (dev build) SHA', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // App identity
    expect(find.text('GeekPlayer'), findsWidgets);
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    // Without a --dart-define=GIT_SHA, kGitSha is "unknown" so the SHA
    // row must show "(dev build)" per spec `about-screen` Scenario
    // "Dev build falls back to `(dev build)`".
    expect(find.text('(dev build)'), findsOneWidget);

    // Section headings in Japanese.
    expect(find.text('バージョン'), findsOneWidget);
    expect(find.text('ビルド番号'), findsOneWidget);
    expect(find.text('コミット'), findsOneWidget);

    // Apache-2.0 NOTICE
    expect(find.text('Copyright 2026 GeekPlayer Contributors'), findsOneWidget);
  });

  testWidgets('exposes GitHub / Roadmap / Full License rows', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-link-github')), findsOneWidget);
    expect(find.byKey(const Key('about-link-roadmap')), findsOneWidget);
    expect(find.byKey(const Key('about-link-license')), findsOneWidget);
    expect(find.byKey(const Key('about-oss-licenses')), findsOneWidget);
  });

  testWidgets('renders placeholders when package_info returns empty version', (
    WidgetTester tester,
  ) async {
    // Spec `about-screen` Scenario "Version retrieval failure does not
    // crash the screen": empty version is replaced with "-" placeholder.
    PackageInfo.setMockInitialValues(
      appName: '',
      packageName: 'dev.geekjapan.geekplayer',
      version: '',
      buildNumber: '',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Two "-" placeholders (version + buildNumber) — coexist with the
    // SHA "(dev build)" line.
    expect(find.text('-'), findsNWidgets(2));
    expect(find.text('(dev build)'), findsOneWidget);
  });
}
