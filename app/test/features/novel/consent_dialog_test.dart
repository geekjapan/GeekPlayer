import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/policy_version.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/novel/presentation/consent_dialog.dart';

Widget _harness({required AppDatabase db, required Widget child}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() => db.close());

  testWidgets('"決定" persists checked sites and closes dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        db: db,
        child: Builder(
          builder: (BuildContext context) {
            return Center(
              child: ElevatedButton(
                onPressed: () => ConsentDialog.show(context),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Check narou + kakuyomu, leave noc unchecked.
    await tester.tap(find.byKey(const ValueKey<String>('consent-narou')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('consent-kakuyomu')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('consent-confirm')));
    await tester.pumpAndSettle();

    // Dialog dismissed.
    expect(find.byType(ConsentDialog), findsNothing);

    final List<SiteConsentRow> rows = await db.siteConsentsDao.getAll();
    expect(rows.length, 3);
    final Map<String, bool> map = <String, bool>{
      for (final SiteConsentRow r in rows) r.site: r.granted,
    };
    expect(map['narou'], isTrue);
    expect(map['noc'], isFalse);
    expect(map['kakuyomu'], isTrue);
    expect(
      rows.every((SiteConsentRow r) => r.policyVersion == kPolicyVersion),
      isTrue,
    );
  });

  testWidgets('"すべて拒否" persists three denied rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        db: db,
        child: Builder(
          builder: (BuildContext context) {
            return Center(
              child: ElevatedButton(
                onPressed: () => ConsentDialog.show(context),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('consent-deny-all')));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentDialog), findsNothing);

    final List<SiteConsentRow> rows = await db.siteConsentsDao.getAll();
    expect(rows.length, Site.values.length);
    expect(
      rows.every((SiteConsentRow r) => !r.granted),
      isTrue,
    );
  });

  testWidgets('barrier tap does not dismiss', (WidgetTester tester) async {
    await tester.pumpWidget(
      _harness(
        db: db,
        child: Builder(
          builder: (BuildContext context) {
            return Center(
              child: ElevatedButton(
                onPressed: () => ConsentDialog.show(context),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentDialog), findsOneWidget);

    // Tap top-left corner (outside the dialog content). flutter_test's
    // showDialog respects barrierDismissible=false: the gesture is
    // swallowed without popping.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentDialog), findsOneWidget);

    // Clean up.
    await tester.tap(find.byKey(const Key('consent-deny-all')));
    await tester.pumpAndSettle();
  });
}
