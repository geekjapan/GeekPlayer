import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/about/presentation/about_screen.dart';
import 'package:geekplayer/features/settings/presentation/settings_screen.dart';
import 'package:geekplayer/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Spec `english-localization` Requirement "Shared UI surfaces use
/// AppLocalizations" — Settings and About render localized labels for both
/// `ja` and `en`.

Widget _settingsHarness(AppDatabase db, Locale locale) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

Widget _aboutHarness(Locale locale) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AboutScreen(),
    ),
  );
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'GeekPlayer',
      packageName: 'dev.geekjapan.geekplayer',
      version: '0.1.0',
      buildNumber: '12',
      buildSignature: '',
    );
  });

  testWidgets('Settings renders English labels under Locale(en)', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);
    await tester.pumpWidget(_settingsHarness(db, const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Display'), findsWidgets);
    expect(find.text('設定'), findsNothing);
  });

  testWidgets('Settings renders Japanese labels under Locale(ja)', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);
    await tester.pumpWidget(_settingsHarness(db, const Locale('ja')));
    await tester.pumpAndSettle();

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('表示'), findsWidgets);
  });

  testWidgets('About renders English title under Locale(en)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_aboutHarness(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsWidgets);
    expect(find.text('アプリ情報'), findsNothing);
  });

  testWidgets('About renders Japanese title under Locale(ja)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_aboutHarness(const Locale('ja')));
    await tester.pumpAndSettle();

    expect(find.text('アプリ情報'), findsWidgets);
  });
}
