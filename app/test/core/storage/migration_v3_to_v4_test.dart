import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// drift v3 -> v4 and v1 -> v4 skip migration tests
/// (CONVENTIONS.md §5; add-pdf-epub-reader design.md D2).
///
/// Mirrors the structure of `migration_v2_to_v3_test.dart`: hand-roll the
/// older schemas in in-memory sqlite3, seed rows, open [AppDatabase]
/// (schema v4) against the same connection so drift's migrator fires.
/// After migration, every pre-existing row MUST survive and `book_metadata`
/// / `book_bookmarks` MUST be present and empty.
void main() {
  group('migration v3 -> v4', () {
    test(
      'creates book_metadata + book_bookmarks and preserves all v1-v3 data',
      () async {
        final Database raw = sqlite3.openInMemory();
        _createV1Schema(raw);
        _createV2Schema(raw);
        _createV3Schema(raw);
        raw.execute('PRAGMA user_version = 3;');

        // Seed rows across all prior versions.
        raw.execute(
          'INSERT INTO "playback_positions" VALUES (?, ?, ?)',
          <Object>[
            'file:///movie.mp4',
            45000,
            DateTime.utc(2026, 5, 1).millisecondsSinceEpoch,
          ],
        );
        raw.execute('INSERT INTO "recent_items" VALUES (?, ?, ?)', <Object>[
          'file:///movie.mp4',
          'video',
          DateTime.utc(2026, 5, 1).millisecondsSinceEpoch,
        ]);
        raw.execute(
          'INSERT INTO "novel_works" VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'narou',
            'n1234ab',
            'Sample Title',
            'Sample Author',
            null,
            5,
            DateTime.utc(2026, 5, 10).millisecondsSinceEpoch,
            null,
          ],
        );
        raw.execute('INSERT INTO "app_settings" VALUES (?, ?)', <Object>[
          'theme',
          'dark',
        ]);

        final AppDatabase db = AppDatabase.forTesting(
          DatabaseConnection(NativeDatabase.opened(raw)),
        );
        addTearDown(db.close);

        // Touch book DAOs to trigger migration.
        final List<BookMetadataRow> books = await db.bookMetadataDao.listAll();
        expect(books, isEmpty);

        final List<BookBookmarkRow> bookmarks = await db.bookBookmarksDao
            .listByBook('x');
        expect(bookmarks, isEmpty);

        // v1 rows survive.
        expect(
          await db.playbackPositionsDao.getByUri('file:///movie.mp4'),
          const Duration(milliseconds: 45000),
        );
        final List<RecentItemRow> recents = await db.recentItemsDao.list();
        expect(recents.length, 1);
        expect(recents.first.kind, 'video');

        // v2 rows survive.
        final List<NovelWorkRow> works = await db.novelWorksDao.listAll();
        expect(works.length, 1);
        expect(works.first.title, 'Sample Title');

        // v3 rows survive.
        final List<AppSettingRow> settings = await db.appSettingsDao.getAll();
        expect(settings.length, 1);
        expect(settings.first.value, 'dark');

        // user_version updated to 5 (AppDatabase schemaVersion is now 5).
        final ResultSet versionRow = raw.select('PRAGMA user_version');
        expect(versionRow.first.values.first, 6);
      },
    );
  });

  group('migration v1 -> v4 (skip)', () {
    test('runs all branches and new tables exist; v1 data survives', () async {
      final Database raw = sqlite3.openInMemory();
      _createV1Schema(raw);
      raw.execute('PRAGMA user_version = 1;');

      raw.execute('INSERT INTO "playback_positions" VALUES (?, ?, ?)', <Object>[
        'file:///audio.mp3',
        12000,
        DateTime.utc(2026, 4, 1).millisecondsSinceEpoch,
      ]);

      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.opened(raw)),
      );
      addTearDown(db.close);

      expect(await db.bookMetadataDao.listAll(), isEmpty);
      expect(await db.bookBookmarksDao.listByBook('x'), isEmpty);
      expect(await db.appSettingsDao.getAll(), isEmpty);
      expect(await db.novelWorksDao.listAll(), isEmpty);

      // v1 data survives.
      expect(
        await db.playbackPositionsDao.getByUri('file:///audio.mp3'),
        const Duration(milliseconds: 12000),
      );

      final ResultSet versionRow = raw.select('PRAGMA user_version');
      expect(versionRow.first.values.first, 6);
    });
  });

  group('fresh install (onCreate)', () {
    test('schemaVersion is 6 and book tables are empty', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      // schemaVersion is now 5 (add-manga-zip-viewer bumped from 4).
      expect(db.schemaVersion, 6);
      expect(await db.bookMetadataDao.listAll(), isEmpty);
      expect(await db.bookBookmarksDao.listByBook('x'), isEmpty);
      expect(await db.playbackPositionsDao.getByUri('x'), isNull);
    });
  });

  group('BookMetadataDao', () {
    test('upsert and getByUri round-trip', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime now = DateTime.utc(2026, 6, 1);
      await db.bookMetadataDao.upsert(
        uri: 'file:///book.pdf',
        path: '/book.pdf',
        format: 'pdf',
        title: 'Test Book',
        author: 'Author A',
        fileSizeBytes: 1024,
        fileLastModified: now,
        importedAt: now,
      );

      final BookMetadataRow? row = await db.bookMetadataDao.getByUri(
        'file:///book.pdf',
      );
      expect(row, isNotNull);
      expect(row!.title, 'Test Book');
      expect(row.format, 'pdf');
    });

    test('upsert is idempotent — second call updates, no duplicate', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      await db.bookMetadataDao.upsert(
        uri: 'file:///book.pdf',
        path: '/book.pdf',
        format: 'pdf',
        title: 'Old Title',
        author: '',
        fileSizeBytes: 100,
        fileLastModified: t,
        importedAt: t,
      );
      await db.bookMetadataDao.upsert(
        uri: 'file:///book.pdf',
        path: '/book.pdf',
        format: 'pdf',
        title: 'New Title',
        author: '',
        fileSizeBytes: 100,
        fileLastModified: t,
        importedAt: t,
      );

      final List<BookMetadataRow> all = await db.bookMetadataDao.listAll();
      expect(all.length, 1);
      expect(all.first.title, 'New Title');
    });

    test('deleteBook cascades to bookmarks', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      const String uri = 'file:///book.epub';
      await db.bookMetadataDao.upsert(
        uri: uri,
        path: '/book.epub',
        format: 'epub',
        title: 'EPUB',
        author: '',
        fileSizeBytes: 200,
        fileLastModified: t,
        importedAt: t,
      );
      await db.bookBookmarksDao.addBookmark(
        bookUri: uri,
        label: 'Chapter 1',
        pageIndex: 1,
        scrollFraction: 0.5,
        createdAt: t,
      );

      await db.bookMetadataDao.deleteBook(uri);

      expect(await db.bookMetadataDao.getByUri(uri), isNull);
      expect(await db.bookBookmarksDao.listByBook(uri), isEmpty);
    });
  });

  group('BookBookmarksDao', () {
    test('addBookmark / listByBook / deleteById', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      const String uri = 'file:///b.pdf';
      final int id = await db.bookBookmarksDao.addBookmark(
        bookUri: uri,
        label: 'Intro',
        pageIndex: 3,
        scrollFraction: 0.25,
        createdAt: t,
      );
      expect(id, greaterThan(0));

      final List<BookBookmarkRow> marks = await db.bookBookmarksDao.listByBook(
        uri,
      );
      expect(marks.length, 1);
      expect(marks.first.label, 'Intro');
      expect(marks.first.pageIndex, 3);

      final int removed = await db.bookBookmarksDao.deleteById(id);
      expect(removed, 1);
      expect(await db.bookBookmarksDao.listByBook(uri), isEmpty);
    });
  });
}

void _createV1Schema(Database raw) {
  raw.execute('''
    CREATE TABLE "playback_positions" (
      "uri" TEXT NOT NULL,
      "position_ms" INTEGER NOT NULL,
      "updated_at" INTEGER NOT NULL,
      PRIMARY KEY ("uri")
    );
  ''');
  raw.execute('''
    CREATE TABLE "recent_items" (
      "uri" TEXT NOT NULL,
      "kind" TEXT NOT NULL,
      "opened_at" INTEGER NOT NULL,
      PRIMARY KEY ("uri")
    );
  ''');
}

void _createV2Schema(Database raw) {
  raw.execute('''
    CREATE TABLE "novel_works" (
      "site" TEXT NOT NULL,
      "external_id" TEXT NOT NULL,
      "title" TEXT NOT NULL,
      "author" TEXT NOT NULL,
      "synopsis" TEXT NULL,
      "episode_count" INTEGER NOT NULL,
      "added_at" INTEGER NOT NULL,
      "last_synced_at" INTEGER NULL,
      PRIMARY KEY ("site", "external_id")
    );
  ''');
  raw.execute('''
    CREATE TABLE "novel_episodes" (
      "site" TEXT NOT NULL,
      "external_id" TEXT NOT NULL,
      "episode_index" INTEGER NOT NULL,
      "title" TEXT NOT NULL,
      "body" TEXT NOT NULL,
      "fetched_at" INTEGER NOT NULL,
      PRIMARY KEY ("site", "external_id", "episode_index")
    );
  ''');
  raw.execute('''
    CREATE TABLE "novel_bookmarks" (
      "site" TEXT NOT NULL,
      "external_id" TEXT NOT NULL,
      "episode_index" INTEGER NOT NULL,
      "scroll_fraction" REAL NOT NULL,
      "updated_at" INTEGER NOT NULL,
      PRIMARY KEY ("site", "external_id")
    );
  ''');
  raw.execute('''
    CREATE TABLE "site_consents" (
      "site" TEXT NOT NULL,
      "granted" INTEGER NOT NULL,
      "decided_at" INTEGER NOT NULL,
      "policy_version" TEXT NOT NULL,
      PRIMARY KEY ("site")
    );
  ''');
}

void _createV3Schema(Database raw) {
  raw.execute('''
    CREATE TABLE "app_settings" (
      "key" TEXT NOT NULL,
      "value" TEXT NOT NULL,
      PRIMARY KEY ("key")
    );
  ''');
}
