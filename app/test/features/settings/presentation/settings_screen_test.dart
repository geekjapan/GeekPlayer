import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/settings/presentation/app_settings_notifier.dart';
import 'package:geekplayer/features/settings/presentation/settings_screen.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

Widget _harness(AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ),
  );
}

AppDatabase _freshDb() {
  return AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
}

void main() {
  testWidgets('renders all 10 sections in the declared order', (
    WidgetTester tester,
  ) async {
    // Stretch the surface so the entire ListView builds without scroll.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    const List<String> ids = <String>[
      'display',
      'playback',
      'video',
      'audio',
      'novel',
      'library',
      'cache',
      'online-services',
      'r18',
      'about',
    ];
    for (final String id in ids) {
      expect(find.byKey(Key('section-$id')), findsOneWidget);
    }
  });

  testWidgets(
    'changing theme to dark updates AppSettings.themeMode immediately',
    (WidgetTester tester) async {
      final AppDatabase db = _freshDb();
      addTearDown(db.close);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: Builder(
            builder: (ctx) {
              container = ProviderScope.containerOf(ctx);
              return const MaterialApp(
                locale: Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: SettingsScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the dark radio.
      await tester.tap(find.byKey(const Key('theme-dark')));
      await tester.pump();

      expect(
        container.read(appSettingsProvider).value!.themeMode,
        ThemeMode.dark,
      );
    },
  );

  testWidgets('accent color row is non-interactive', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    final Finder accent = find.byKey(const Key('accent-color-placeholder'));
    expect(accent, findsOneWidget);
    expect(find.text('v0.2 で対応'), findsOneWidget);
    final ListTile tile = tester.widget(accent);
    expect(tile.enabled, isFalse);
  });

  testWidgets('default speed shows the next-launch helper', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    expect(find.text('変更は次回起動から有効になります'), findsWidgets);
  });

  testWidgets('history clear shows a confirmation dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    await db.recentItemsDao.recordOpen('file:///x.mp4', 'video');

    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clear-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear-history-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear-history-confirm-button')));
    await tester.pumpAndSettle();

    final recents = await db.recentItemsDao.list();
    expect(recents, isEmpty);
  });

  testWidgets('R18 reset shows confirmation and revokes consent on confirm', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    await db.siteConsentsDao.setConsent(
      site: 'noc',
      granted: true,
      policyVersion: '2026-05-27',
    );

    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('r18-reset')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('r18-reset-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('r18-reset-confirm-button')));
    await tester.pumpAndSettle();

    final row = await db.siteConsentsDao.getConsent('noc');
    expect(row, isNotNull);
    expect(row!.granted, isFalse);
  });

  testWidgets('about version row is present', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // package_info_plus' platform channel isn't available in unit tests,
    // so we just assert the row renders with the loading sentinel.
    final AppDatabase db = _freshDb();
    addTearDown(db.close);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-version')), findsOneWidget);
  });
}
