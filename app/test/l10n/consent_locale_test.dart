import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/novel/presentation/consent_dialog.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

/// Spec `english-localization` Requirement "Shared UI surfaces use
/// AppLocalizations" — the consent / responsible-fetching disclosure renders
/// localized copy. Covers English (and re-checks Japanese).
Widget _harness({
  required AppDatabase db,
  required Locale locale,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });
  tearDown(() => db.close());

  testWidgets('ConsentDialog renders English copy under Locale(en)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        db: db,
        locale: const Locale('en'),
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => ConsentDialog.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Consent for Online Novel Sites'), findsOneWidget);
    expect(find.text('Deny all'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('すべて拒否'), findsNothing);
  });

  testWidgets('ConsentDialog renders Japanese copy under Locale(ja)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        db: db,
        locale: const Locale('ja'),
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => ConsentDialog.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('オンライン小説サイトへの同意'), findsOneWidget);
    expect(find.text('すべて拒否'), findsOneWidget);
    expect(find.text('決定'), findsOneWidget);
  });
}
