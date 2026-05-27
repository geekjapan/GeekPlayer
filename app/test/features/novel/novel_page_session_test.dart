import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/media_session.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work_id.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/novel/data/novel_page_session.dart';

void main() {
  late AppDatabase db;
  const WorkId workId = WorkId(site: Site.kakuyomu, externalId: 'kak-1');

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() => db.close());

  test('replays initial PagePosition on subscription', () async {
    final NovelPageSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 5,
    );
    addTearDown(s.dispose);

    final PagePosition first = await s.pagePositionStream.first;
    expect(first.pageIndex, 1);
    expect(first.scrollFraction, 0.0);

    // Subscribing again still sees the most recent position (replay).
    await s.goToPage(3);
    final PagePosition next = await s.pagePositionStream.first;
    expect(next.pageIndex, 3);
  });

  test('goToPage emits new position with scrollFraction reset', () async {
    final NovelPageSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 10,
    );
    addTearDown(s.dispose);

    final List<PagePosition> seen = <PagePosition>[];
    final sub = s.pagePositionStream.listen(seen.add);

    await s.goToPage(3);
    await Future<void>.delayed(Duration.zero);

    expect(seen.last.pageIndex, 3);
    expect(seen.last.scrollFraction, 0.0);
    await sub.cancel();
  });

  test('updateScrollFraction emits and validates range', () async {
    final NovelPageSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 3,
    );
    addTearDown(s.dispose);

    await s.goToPage(2);

    final List<PagePosition> seen = <PagePosition>[];
    final sub = s.pagePositionStream.listen(seen.add);

    await s.updateScrollFraction(0.42);
    await Future<void>.delayed(Duration.zero);

    expect(seen.last.pageIndex, 2);
    expect(seen.last.scrollFraction, closeTo(0.42, 1e-9));

    await expectLater(() => s.updateScrollFraction(1.5), throwsArgumentError);
    await expectLater(() => s.updateScrollFraction(-0.1), throwsArgumentError);
    await sub.cancel();
  });

  test('seek(Duration) throws UnsupportedError naming goToPage', () async {
    final NovelPageSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 5,
    );
    addTearDown(s.dispose);

    await expectLater(
      () => s.seek(const Duration(seconds: 5)),
      throwsA(
        isA<UnsupportedError>().having(
          (UnsupportedError e) => e.message,
          'message',
          contains('goToPage'),
        ),
      ),
    );
  });

  test('dispose upserts current position to novel_bookmarks', () async {
    final NovelPageSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 10,
    );

    await s.goToPage(4);
    await s.updateScrollFraction(0.75);
    await s.dispose();

    final NovelBookmarkRow? row = await db.novelBookmarksDao.getBookmark(
      workId.site.code,
      workId.externalId,
    );
    expect(row, isNotNull);
    expect(row!.episodeIndex, 4);
    expect(row.scrollFraction, closeTo(0.75, 1e-9));
  });

  test('dispose is idempotent', () async {
    final NovelPageSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 2,
    );
    await s.dispose();
    await s.dispose();
  });

  test('goToPage clamps to [1, totalPages]', () async {
    final NovelPageSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 5,
    );
    addTearDown(s.dispose);

    await s.goToPage(99);
    expect(s.currentForTest.pageIndex, 5);

    await s.goToPage(-3);
    expect(s.currentForTest.pageIndex, 1);
  });

  test('MediaSession switch is exhaustive over PageSession case', () {
    // Compile-time check: a switch over MediaSession that lists Video
    // + Page case must remain exhaustive after PageSession joined the
    // sealed hierarchy. AudioSession is added by a sibling change.
    final MediaSession s = NovelPageSession(
      workId: workId,
      bookmarksDao: db.novelBookmarksDao,
      totalPages: 1,
    );
    addTearDown(s.dispose);

    final String label = switch (s) {
      VideoSession() => 'video',
      PageSession() => 'page',
    };
    expect(label, 'page');
  });
}
