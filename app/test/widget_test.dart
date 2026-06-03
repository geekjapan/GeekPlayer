import 'package:drift/native.dart' show NativeDatabase;
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/library/home_screen.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

void main() {
  testWidgets('HomeScreen renders the video section with open button + '
      'empty-state recent placeholder', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((Ref ref) {
            ref.onDispose(db.close);
            return db;
          }),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    // Allow the recent-videos future to settle.
    await tester.pumpAndSettle();

    expect(find.text('GeekPlayer'), findsOneWidget);
    // Video section
    expect(find.text('動画'), findsOneWidget);
    expect(find.text('動画を開く'), findsOneWidget);
    expect(find.text('最近開いた動画はまだありません'), findsOneWidget);
    // Audio section (wave 2)
    expect(find.text('音楽'), findsOneWidget);
    expect(find.text('音楽を開く'), findsOneWidget);
    expect(find.text('最近開いた音楽はまだありません'), findsOneWidget);
  });
}
