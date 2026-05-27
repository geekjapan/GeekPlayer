import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/age_gate/presentation/age_gate_dialog.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';

Widget _wrap({required AppDatabase db, required Widget child}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((Ref ref) => db)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _OpenButton extends ConsumerWidget {
  const _OpenButton({required this.onResult});
  final void Function(bool) onResult;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      key: const Key('open'),
      onPressed: () async {
        final bool r = await showAgeGate(context, ref);
        onResult(r);
      },
      child: const Text('open'),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('「はい」で grant + true 返し', (WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(
      _wrap(
        db: db,
        child: _OpenButton(onResult: (bool r) => result = r),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(AgeGateDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('age-gate-yes')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    // DB に grant が永続化されている
    final ConsentRepository repo = ConsentRepository(db.siteConsentsDao);
    expect(await repo.hasFreshConsent(Site.noc), isTrue);
  });

  testWidgets('「いいえ」で grant せず false 返し', (WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(
      _wrap(
        db: db,
        child: _OpenButton(onResult: (bool r) => result = r),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('age-gate-no')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    final ConsentRepository repo = ConsentRepository(db.siteConsentsDao);
    expect(await repo.hasFreshConsent(Site.noc), isFalse);
  });

  testWidgets('既に同意済なら即座に true (ダイアログを開かない)', (WidgetTester tester) async {
    final ConsentRepository repo = ConsentRepository(db.siteConsentsDao);
    await repo.grant(Site.noc);
    bool? result;
    await tester.pumpWidget(
      _wrap(
        db: db,
        child: _OpenButton(onResult: (bool r) => result = r),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(AgeGateDialog), findsNothing);
    expect(result, isTrue);
  });
}
