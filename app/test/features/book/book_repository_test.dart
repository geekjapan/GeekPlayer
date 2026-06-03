import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/book/data/book_repository_impl.dart';
import 'package:geekplayer/features/book/domain/book_bookmark.dart';
import 'package:geekplayer/features/book/domain/book_locator.dart';
import 'package:geekplayer/features/book/domain/book_metadata.dart';

/// Tasks 6.2 (metadata + recency) and 6.3 (bookmark persistence).
void main() {
  late AppDatabase db;
  late BookRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repo = BookRepositoryImpl(
      metadataDao: db.bookMetadataDao,
      bookmarksDao: db.bookBookmarksDao,
      recentItemsDao: db.recentItemsDao,
    );
  });

  tearDown(() => db.close());

  Future<void> seedBook(String uri, {String format = 'pdf'}) async {
    final DateTime t = DateTime.utc(2026, 6, 1);
    await db.bookMetadataDao.upsert(
      uri: uri,
      path: uri.replaceFirst('file://', ''),
      format: format,
      title: uri.split('/').last,
      author: '',
      fileSizeBytes: 512,
      fileLastModified: t,
      lastOpenedAt: t,
      importedAt: t,
    );
  }

  group('listRecentBooks', () {
    test('returns books sorted newest-opened first', () async {
      await seedBook('file:///a.pdf');
      await db.bookMetadataDao.touchLastOpened(
        'file:///a.pdf',
        DateTime.utc(2026, 6, 1),
      );
      await seedBook('file:///b.pdf');
      await db.bookMetadataDao.touchLastOpened(
        'file:///b.pdf',
        DateTime.utc(2026, 6, 2),
      );

      final List<BookMetadata> books = await repo.listRecentBooks();
      expect(books.length, 2);
      expect(books.first.uri, 'file:///b.pdf');
    });
  });

  group('saveProgress / loadProgress', () {
    test('round-trip stores and restores locator', () async {
      await seedBook('file:///read.pdf');
      const BookLocator expected = BookLocator(
        pageIndex: 7,
        scrollFraction: 0.33,
      );
      await repo.saveProgress('file:///read.pdf', expected);
      final BookLocator loaded = await repo.loadProgress('file:///read.pdf');
      expect(loaded.pageIndex, expected.pageIndex);
      expect(loaded.scrollFraction, closeTo(expected.scrollFraction, 0.001));
    });

    test('returns page 1 when no progress exists', () async {
      final BookLocator loc = await repo.loadProgress(
        'file:///no-progress.pdf',
      );
      expect(loc, const BookLocator(pageIndex: 1));
    });

    test('saveProgress is idempotent — second save overwrites first', () async {
      await seedBook('file:///overwrite.pdf');
      await repo.saveProgress(
        'file:///overwrite.pdf',
        const BookLocator(pageIndex: 3, scrollFraction: 0.1),
      );
      await repo.saveProgress(
        'file:///overwrite.pdf',
        const BookLocator(pageIndex: 10, scrollFraction: 0.9),
      );
      final BookLocator loaded = await repo.loadProgress(
        'file:///overwrite.pdf',
      );
      expect(loaded.pageIndex, 10);
    });
  });

  group('bookmarks', () {
    test('addBookmark / listBookmarks / deleteBookmark round-trip', () async {
      await seedBook('file:///bm.epub', format: 'epub');
      const String uri = 'file:///bm.epub';

      final BookBookmark bm = await repo.addBookmark(
        bookUri: uri,
        label: 'Great passage',
        locator: const BookLocator(pageIndex: 4, scrollFraction: 0.6),
      );

      final List<BookBookmark> marks = await repo.listBookmarks(uri);
      expect(marks.length, 1);
      expect(marks.first.label, 'Great passage');
      expect(marks.first.locator.pageIndex, 4);

      await repo.deleteBookmark(bm.id);
      expect(await repo.listBookmarks(uri), isEmpty);
    });

    test('__progress bookmark is excluded from listBookmarks', () async {
      await seedBook('file:///hidden.pdf');
      // saveProgress writes a __progress bookmark internally.
      await repo.saveProgress(
        'file:///hidden.pdf',
        const BookLocator(pageIndex: 2),
      );
      final List<BookBookmark> visible = await repo.listBookmarks(
        'file:///hidden.pdf',
      );
      expect(visible, isEmpty);
    });
  });

  group('deleteBook', () {
    test('removes metadata and all bookmarks', () async {
      const String uri = 'file:///delete-me.pdf';
      await seedBook(uri);
      await repo.addBookmark(
        bookUri: uri,
        label: 'keep?',
        locator: const BookLocator(pageIndex: 1),
      );

      await repo.deleteBook(uri);

      final List<BookMetadata> books = await repo.listRecentBooks();
      expect(books.where((BookMetadata b) => b.uri == uri), isEmpty);
    });
  });
}
