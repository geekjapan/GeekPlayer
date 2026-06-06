import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/model_repository.dart';
import 'package:geekplayer/core/ml/providers.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/settings/presentation/sections/experimental_section.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

/// Offline downloader stub — never invoked by these render-only tests.
class _Downloader implements ModelDownloader {
  const _Downloader();
  @override
  Future<Uint8List> download(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async => Uint8List(0);
}

AppDatabase _freshDb() =>
    AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

void main() {
  late AppDatabase db;
  late Directory cacheDir;

  setUp(() async {
    db = _freshDb();
    cacheDir = await Directory.systemTemp.createTemp('gp_exp_sec_');
  });

  tearDown(() async {
    await db.close();
    if (cacheDir.existsSync()) await cacheDir.delete(recursive: true);
  });

  // The mutate/persist path and the download path schedule a debounce timer and
  // perform real file I/O respectively; both are covered by unit tests
  // (app_settings_repository_test, model_repository_test). These widget tests
  // assert the section renders the right controls in their initial state.
  Widget harness() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        modelRepositoryProvider.overrideWithValue(
          ModelRepository(
            downloader: const _Downloader(),
            cacheDirProvider: () async => cacheDir,
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ExperimentalSection()),
        ),
      ),
    );
  }

  testWidgets('renders the Experimental warning and a default-OFF toggle', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    final SwitchListTile sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('experimental-ai-upscale-enable')),
    );
    expect(sw.value, isFalse);
  });

  testWidgets('offers 2x and 4x scale chips with 2x selected by default', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final ChoiceChip x2 = tester.widget<ChoiceChip>(
      find.byKey(const Key('experimental-ai-upscale-scale-2')),
    );
    final ChoiceChip x4 = tester.widget<ChoiceChip>(
      find.byKey(const Key('experimental-ai-upscale-scale-4')),
    );
    expect(x2.selected, isTrue);
    expect(x4.selected, isFalse);
  });

  testWidgets('shows the model tile with a download affordance when absent', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('experimental-ai-upscale-model')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('experimental-ai-upscale-download')),
      findsOneWidget,
    );
  });
}
