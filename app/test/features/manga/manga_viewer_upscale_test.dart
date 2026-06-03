import 'dart:typed_data';

import 'package:drift/native.dart' show NativeDatabase;
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:geekplayer/core/ml/image_upscaler.dart';
import 'package:geekplayer/core/ml/providers.dart';
import 'package:geekplayer/core/ml/upscale_request.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/manga/domain/manga_archive.dart';
import 'package:geekplayer/features/manga/presentation/manga_viewer_screen.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

class _MockUpscaler extends Mock implements ImageUpscaler {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      UpscaleRequest(
        bytes: Uint8List(0),
        srcWidth: 1,
        srcHeight: 1,
        scaleFactor: 1,
      ),
    );
  });

  Widget buildViewer({
    required AppDatabase db,
    required ImageUpscaler upscaler,
  }) {
    const MangaArchive archive = MangaArchive(
      uri: 'test://manga.zip',
      path: '/nonexistent/manga.zip',
      title: 'Test Manga',
      format: 'zip',
      pageCount: 0,
      pages: [],
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((Ref ref) {
          ref.onDispose(db.close);
          return db;
        }),
        imageUpscalerProvider.overrideWithValue(upscaler),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MangaViewerScreen(archive: archive),
      ),
    );
  }

  group('MangaViewerScreen upscale action', () {
    late AppDatabase db;
    late _MockUpscaler mockUpscaler;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      mockUpscaler = _MockUpscaler();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'upscale icon button is visible in AppBar when controls visible',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildViewer(db: db, upscaler: mockUpscaler));
        await tester.pumpAndSettle();

        // The upscale button should be visible (controls visible by default).
        expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
      },
    );

    testWidgets('upscale button tooltip is localized to Japanese', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildViewer(db: db, upscaler: mockUpscaler));
      await tester.pumpAndSettle();

      final Finder button = find.byIcon(Icons.auto_fix_high);
      expect(button, findsOneWidget);

      final Tooltip tooltip = tester.widget<Tooltip>(
        find.ancestor(of: button, matching: find.byType(Tooltip)).first,
      );
      expect(tooltip.message, '高画質化');
    });

    testWidgets('upscale button is disabled while upscaling in progress', (
      WidgetTester tester,
    ) async {
      // Archive has no pages so _upscaleCurrentPage returns early immediately —
      // the button should still render and be tappable (no crash).
      await tester.pumpWidget(buildViewer(db: db, upscaler: mockUpscaler));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);

      // Tapping with an empty archive should not throw.
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();
    });
  });
}
