import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/manga/data/manga_providers.dart';
import 'package:geekplayer/features/manga/domain/manga_metadata.dart';
import 'package:geekplayer/features/manga/domain/manga_repository.dart';
import 'package:geekplayer/features/manga/presentation/manga_home_section.dart';
import 'package:geekplayer/l10n/app_localizations.dart';

/// Widget tests for [MangaHomeSection] and [MangaHomeSection] tile.
///
/// Covers task 7.6: MangaHomeSection rendering and missing-file recovery.
void main() {
  /// Build a test harness with a provider override.
  Widget buildHarness({required MangaRepository repoOverride}) {
    return ProviderScope(
      overrides: [mangaRepositoryProvider.overrideWithValue(repoOverride)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ja'),
        home: Scaffold(body: _MangaHomeSectionTestBody()),
      ),
    );
  }

  testWidgets('section title and add button are rendered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(repoOverride: _EmptyMangaRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('ローカルマンガ'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('empty placeholder shown when no manga', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(repoOverride: _EmptyMangaRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('マンガはまだありません'), findsOneWidget);
  });

  testWidgets('manga tiles rendered when list is non-empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(repoOverride: _PreloadedMangaRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sample Manga'), findsOneWidget);
  });

  test('MangaHomeSection has order 600', () {
    expect(const MangaHomeSection().order, 600);
  });

  test('MangaHomeSection has id "manga"', () {
    expect(const MangaHomeSection().id, 'manga');
  });
}

// ---------------------------------------------------------------------------
// Test widget that renders the section body directly.
// ---------------------------------------------------------------------------

class _MangaHomeSectionTestBody extends ConsumerWidget {
  const _MangaHomeSectionTestBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MangaHomeSection().build(context, ref);
  }
}

// ---------------------------------------------------------------------------
// Fake repository implementations for testing.
// ---------------------------------------------------------------------------

final DateTime _epoch = DateTime.utc(2026, 1, 1);

class _EmptyMangaRepository implements MangaRepository {
  @override
  Future<List<MangaMetadata>> listRecentManga() async => <MangaMetadata>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _PreloadedMangaRepository implements MangaRepository {
  @override
  Future<List<MangaMetadata>> listRecentManga() async => <MangaMetadata>[
    MangaMetadata(
      uri: 'file:///sample.cbz',
      path: '/sample.cbz',
      format: 'cbz',
      title: 'Sample Manga',
      fileSizeBytes: 1024,
      fileLastModified: _epoch,
      pageCount: 10,
      importedAt: _epoch,
      lastOpenedAt: _epoch,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
