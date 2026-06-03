import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';
import 'package:geekplayer/features/novel_kakuyomu/presentation/kakuyomu_consent_dialog.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

void main() {
  testWidgets('declining hides Kakuyomu (revokes consent)', (
    WidgetTester tester,
  ) async {
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
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => KakuyomuConsentDialog.show(context),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open dialog.
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    expect(find.text('カクヨムへの同意'), findsOneWidget);

    // Tap 同意しない.
    await tester.tap(find.byKey(const Key('kakuyomu-consent-decline')));
    await tester.pumpAndSettle();
    expect(find.text('カクヨムへの同意'), findsNothing);

    // Consent was revoked.
    final ConsentRepository repo = ConsentRepository(db.siteConsentsDao);
    expect(await repo.hasFreshConsent(Site.kakuyomu), isFalse);
  });

  testWidgets('accepting persists grant', (WidgetTester tester) async {
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
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => KakuyomuConsentDialog.show(context),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kakuyomu-consent-accept')));
    await tester.pumpAndSettle();

    final ConsentRepository repo = ConsentRepository(db.siteConsentsDao);
    expect(await repo.hasFreshConsent(Site.kakuyomu), isTrue);
  });
}
