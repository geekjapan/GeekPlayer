import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/age_gate/presentation/age_gate_settings_section.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';

Widget _wrap({required AppDatabase db}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((Ref ref) => db)],
    child: const MaterialApp(home: Scaffold(body: AgeGateSettingsSection())),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('未同意状態を表示', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    expect(find.text('未同意'), findsOneWidget);
  });

  testWidgets('同意済を日付付きで表示し、取り消し確認で revoke される', (WidgetTester tester) async {
    final ConsentRepository repo = ConsentRepository(db.siteConsentsDao);
    await repo.grant(Site.noc);
    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    expect(find.textContaining('同意済'), findsOneWidget);
    await tester.tap(find.byKey(const Key('age-gate-settings-tile')));
    await tester.pumpAndSettle();
    expect(find.text('年齢確認の取り消し'), findsOneWidget);
    await tester.tap(find.byKey(const Key('age-gate-confirm-revoke')));
    await tester.pumpAndSettle();
    expect(await repo.hasFreshConsent(Site.noc), isFalse);
    expect(find.text('未同意'), findsOneWidget);
  });
}
