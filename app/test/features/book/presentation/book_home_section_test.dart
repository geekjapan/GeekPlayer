import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/book/presentation/book_home_section.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

/// Task 6.5 — widget tests for BookHomeSection: empty state and populated state.
void main() {
  Widget buildApp(AppDatabase db) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((Ref ref) {
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext ctx, WidgetRef ref, _) {
              final section = ref.watch(bookHomeSectionsProvider).first;
              return section.build(ctx, ref);
            },
          ),
        ),
      ),
    );
  }

  testWidgets(
    'renders section title and empty placeholder when no books imported',
    (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      await tester.pumpWidget(buildApp(db));
      await tester.pumpAndSettle();

      expect(find.text('ローカル書籍'), findsOneWidget);
      expect(find.textContaining('書籍はまだありません'), findsOneWidget);
    },
  );

  testWidgets('renders book tile when at least one book is persisted', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);

    final DateTime t = DateTime.utc(2026, 6, 1);
    await db.bookMetadataDao.upsert(
      uri: 'file:///my-book.pdf',
      path: '/my-book.pdf',
      format: 'pdf',
      title: 'My Book',
      author: 'Test Author',
      fileSizeBytes: 1024,
      fileLastModified: t,
      lastOpenedAt: t,
      importedAt: t,
    );

    await tester.pumpWidget(buildApp(db));
    await tester.pumpAndSettle();

    expect(find.text('ローカル書籍'), findsOneWidget);
    expect(find.text('My Book'), findsOneWidget);
    expect(find.textContaining('書籍はまだありません'), findsNothing);
  });
}
