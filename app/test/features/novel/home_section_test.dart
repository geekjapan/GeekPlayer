import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/novel/fake_novel_repository.dart';
import 'package:geekplayer/core/novel/models/episode.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work.dart';
import 'package:geekplayer/core/novel/models/work_id.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/core/storage/providers.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';
import 'package:geekplayer/features/novel/data/library_repository.dart';
import 'package:geekplayer/features/novel/presentation/novel_home_section.dart';

const _narouWork = WorkId(site: Site.narou, externalId: 'n1');

FakeWorkData _fixture(WorkId id, String title) {
  final DateTime now = DateTime.utc(2026, 5, 27);
  return FakeWorkData(
    work: Work(
      id: id,
      title: title,
      author: 'a',
      episodeCount: 1,
      addedAt: now,
    ),
    episodes: <Episode>[Episode(id: EpisodeId(1), title: 'e1')],
    bodies: <int, EpisodeBody>{
      1: EpisodeBody(body: 'body', fetchedAt: now),
    },
  );
}

Widget _hosted(AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: NovelHomeSectionView())),
    ),
  );
}

/// Tiny wrapper so widget tests render the section body without
/// the full HomeScreen scaffolding.
class NovelHomeSectionView extends ConsumerWidget {
  const NovelHomeSectionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const NovelHomeSection s = NovelHomeSection();
    return s.build(context, ref);
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() => db.close());

  testWidgets('empty state shows placeholder and disabled search button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_hosted(db));
    await tester.pumpAndSettle();

    expect(find.text('Library に小説はまだありません。'), findsOneWidget);
    final Finder button =
        find.byKey(const Key('open-search-disabled'));
    expect(button, findsOneWidget);
    final OutlinedButton btnWidget = tester.widget(button);
    expect(btnWidget.onPressed, isNull);
  });

  testWidgets('renders site filter chips for all + 3 sites', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_hosted(db));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-all')), findsOneWidget);
    expect(find.byKey(const Key('filter-narou')), findsOneWidget);
    expect(find.byKey(const Key('filter-noc')), findsOneWidget);
    expect(find.byKey(const Key('filter-kakuyomu')), findsOneWidget);
  });

  testWidgets('Library entry from a granted site renders normally', (
    WidgetTester tester,
  ) async {
    final LibraryRepository library = LibraryRepository(
      worksDao: db.novelWorksDao,
      episodesDao: db.novelEpisodesDao,
      bookmarksDao: db.novelBookmarksDao,
    );
    final ConsentRepository consent =
        ConsentRepository(db.siteConsentsDao);
    final FakeNovelRepository source = FakeNovelRepository(
      site: Site.narou,
      seed: <WorkId, FakeWorkData>{
        _narouWork: _fixture(_narouWork, 'タイトルA'),
      },
    );
    await library.addToLibrary(source, _narouWork);
    await consent.grant(Site.narou);

    await tester.pumpWidget(_hosted(db));
    await tester.pumpAndSettle();

    expect(find.text('タイトルA'), findsOneWidget);
    // Consent-disabled banner must NOT be present for the granted
    // group.
    expect(find.byKey(const Key('consent-disabled-banner')), findsNothing);
  });

  testWidgets(
    'Library entry on a denied site shows consent-disabled banner',
    (WidgetTester tester) async {
      final LibraryRepository library = LibraryRepository(
        worksDao: db.novelWorksDao,
        episodesDao: db.novelEpisodesDao,
        bookmarksDao: db.novelBookmarksDao,
      );
      final ConsentRepository consent =
          ConsentRepository(db.siteConsentsDao);
      final FakeNovelRepository source = FakeNovelRepository(
        site: Site.narou,
        seed: <WorkId, FakeWorkData>{
          _narouWork: _fixture(_narouWork, 'タイトルA'),
        },
      );
      await library.addToLibrary(source, _narouWork);
      await consent.revoke(Site.narou); // granted = false

      await tester.pumpWidget(_hosted(db));
      await tester.pumpAndSettle();

      expect(find.text('タイトルA'), findsOneWidget);
      expect(
        find.byKey(const Key('consent-disabled-banner')),
        findsOneWidget,
      );
    },
  );
}
