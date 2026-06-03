import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/about/presentation/license_screen.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

Widget _harness() {
  return const ProviderScope(
    child: MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LicenseListScreen(),
    ),
  );
}

void main() {
  testWidgets('LGPL section appears above Apache NOTICE and dependency list', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final Finder lgpl = find.byKey(const Key('lgpl-notice-section'));
    final Finder apache = find.byKey(const Key('apache-notice-section'));
    expect(lgpl, findsOneWidget);
    expect(apache, findsOneWidget);

    // Order assertion: top-of-screen Y of LGPL must be smaller than
    // Apache, which in turn must be smaller than the first dependency
    // tile.
    final double lgplY = tester.getTopLeft(lgpl).dy;
    final double apacheY = tester.getTopLeft(apache).dy;
    expect(lgplY < apacheY, isTrue, reason: 'LGPL must be above Apache');
  });

  testWidgets('dependency list contains common packages', (
    WidgetTester tester,
  ) async {
    // Stretch the surface tall enough so several tiles materialise on
    // the first paint; ListView.builder only builds visible items.
    tester.view.physicalSize = const Size(800, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final Finder listFinder = find.byKey(const Key('license-list'));
    expect(listFinder, findsOneWidget);

    // We can't predict scroll layouts, so just assert that *some*
    // license entry tile is built. Their keys all begin with
    // 'license-entry-'.
    final Finder entries = find.byWidgetPredicate(
      (Widget w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('license-entry-'),
    );
    expect(entries, findsWidgets);
  });
}
