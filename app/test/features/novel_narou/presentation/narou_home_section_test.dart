import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';
import 'package:geekplayer/features/novel_narou/presentation/narou_home_section.dart';

Widget _wrap({required AppDatabase db}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((Ref ref) => db)],
    child: const MaterialApp(home: Scaffold(body: NarouHomeSection())),
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

  testWidgets('初期状態で検索 / ランキング / ピックアップ のショートカットが表示される', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('narou-shortcut-search')), findsOneWidget);
    expect(find.byKey(const Key('narou-shortcut-ranking')), findsOneWidget);
    expect(find.byKey(const Key('narou-shortcut-pickup')), findsOneWidget);
  });

  testWidgets('R18 未同意時のラベルは "ノクターン (要確認)"', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('narou-shortcut-r18')), findsOneWidget);
    expect(find.textContaining('要確認'), findsOneWidget);
  });

  testWidgets('R18 grant 後にラベルが "ノクターン" に切り替わる', (WidgetTester tester) async {
    final ConsentRepository repo = ConsentRepository(db.siteConsentsDao);
    await repo.grant(Site.noc);
    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();
    // refresh が microtask で走るのを待つ
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('ノクターン'), findsOneWidget);
  });
}
