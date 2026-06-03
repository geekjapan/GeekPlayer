import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// drift v4 -> v5 and v1 -> v5 skip-migration tests
/// (CONVENTIONS.md §5; add-manga-zip-viewer design.md D2).
///
/// Mirrors the structure of `migration_v3_to_v4_test.dart`: hand-roll the
/// v4 schema in in-memory sqlite3, seed rows, open [AppDatabase] (schema v5)
/// against the same connection so drift's migrator fires. After migration,
/// every pre-existing row MUST survive, and `manga_metadata` /
/// `manga_bookmarks` MUST be present and empty.
void main() {
  group('migration v4 -> v5', () {
    test(
      'creates manga_metadata + manga_bookmarks and preserves all v1-v4 data',
      () async {
        final Database raw = sqlite3.openInMemory();
        _createV1Schema(raw);
        _createV2Schema(raw);
        _createV3Schema(raw);
        _createV4Schema(raw);
        raw.execute('PRAGMA user_version = 4;');

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
        raw.execute(
          'INSERT INTO "book_metadata" VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'file:///book.pdf',
            '/book.pdf',
            'pdf',
            'Test Book',
            'Author',
            1024,
            DateTime.utc(2026, 5, 15).millisecondsSinceEpoch,
            null,
            DateTime.utc(2026, 5, 15).millisecondsSinceEpoch,
          ],
        );

        final AppDatabase db = AppDatabase.forTesting(
          DatabaseConnection(NativeDatabase.opened(raw)),
        );
        addTearDown(db.close);

        // Touch manga DAOs to trigger migration.
        final List<MangaMetadataRow> manga = await db.mangaMetadataDao
            .listAll();
        expect(manga, isEmpty);

        final List<MangaBookmarkRow> bookmarks = await db.mangaBookmarksDao
            .listByManga('x');
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

        // v4 rows survive.
        final BookMetadataRow? book = await db.bookMetadataDao.getByUri(
          'file:///book.pdf',
        );
        expect(book, isNotNull);
        expect(book!.title, 'Test Book');

        // user_version updated to 5.
        final ResultSet versionRow = raw.select('PRAGMA user_version');
        expect(versionRow.first.values.first, 6);
      },
    );
  });

  group('migration v1 -> v5 (skip)', () {
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

      expect(await db.mangaMetadataDao.listAll(), isEmpty);
      expect(await db.mangaBookmarksDao.listByManga('x'), isEmpty);
      expect(await db.bookMetadataDao.listAll(), isEmpty);
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
    test('schemaVersion is 6 and manga tables are empty', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      expect(db.schemaVersion, 6);
      expect(await db.mangaMetadataDao.listAll(), isEmpty);
      expect(await db.mangaBookmarksDao.listByManga('x'), isEmpty);
      expect(await db.playbackPositionsDao.getByUri('x'), isNull);
    });
  });

  group('MangaMetadataDao', () {
    test('upsert and getByUri round-trip', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime now = DateTime.utc(2026, 6, 1);
      await db.mangaMetadataDao.upsert(
        uri: 'file:///manga.cbz',
        path: '/manga.cbz',
        format: 'cbz',
        title: 'Test Manga',
        fileSizeBytes: 2048,
        fileLastModified: now,
        pageCount: 100,
        importedAt: now,
      );

      final MangaMetadataRow? row = await db.mangaMetadataDao.getByUri(
        'file:///manga.cbz',
      );
      expect(row, isNotNull);
      expect(row!.title, 'Test Manga');
      expect(row.format, 'cbz');
      expect(row.pageCount, 100);
    });

    test('upsert is idempotent — second call updates, no duplicate', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      await db.mangaMetadataDao.upsert(
        uri: 'file:///manga.cbz',
        path: '/manga.cbz',
        format: 'cbz',
        title: 'Old Title',
        fileSizeBytes: 100,
        fileLastModified: t,
        pageCount: 10,
        importedAt: t,
      );
      await db.mangaMetadataDao.upsert(
        uri: 'file:///manga.cbz',
        path: '/manga.cbz',
        format: 'cbz',
        title: 'New Title',
        fileSizeBytes: 100,
        fileLastModified: t,
        pageCount: 12,
        importedAt: t,
      );

      final List<MangaMetadataRow> all = await db.mangaMetadataDao.listAll();
      expect(all.length, 1);
      expect(all.first.title, 'New Title');
      expect(all.first.pageCount, 12);
    });

    test('deleteManga cascades to bookmarks', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      const String uri = 'file:///vol1.cbz';
      await db.mangaMetadataDao.upsert(
        uri: uri,
        path: '/vol1.cbz',
        format: 'cbz',
        title: 'Vol 1',
        fileSizeBytes: 500,
        fileLastModified: t,
        pageCount: 50,
        importedAt: t,
      );
      await db.mangaBookmarksDao.addBookmark(
        mangaUri: uri,
        label: 'Chapter 1',
        pageIndex: 5,
        createdAt: t,
      );

      await db.mangaMetadataDao.deleteManga(uri);

      expect(await db.mangaMetadataDao.getByUri(uri), isNull);
      expect(await db.mangaBookmarksDao.listByManga(uri), isEmpty);
    });
  });

  group('MangaBookmarksDao', () {
    test('addBookmark / listByManga / deleteById', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      const String uri = 'file:///m.cbz';
      final int id = await db.mangaBookmarksDao.addBookmark(
        mangaUri: uri,
        label: 'Scene start',
        pageIndex: 8,
        createdAt: t,
      );
      expect(id, greaterThan(0));

      final List<MangaBookmarkRow> marks = await db.mangaBookmarksDao
          .listByManga(uri);
      expect(marks.length, 1);
      expect(marks.first.label, 'Scene start');
      expect(marks.first.pageIndex, 8);

      final int removed = await db.mangaBookmarksDao.deleteById(id);
      expect(removed, 1);
      expect(await db.mangaBookmarksDao.listByManga(uri), isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Schema helpers (mirrors migration_v3_to_v4_test.dart)
// ---------------------------------------------------------------------------

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

void _createV4Schema(Database raw) {
  raw.execute('''
    CREATE TABLE "book_metadata" (
      "uri" TEXT NOT NULL,
      "path" TEXT NOT NULL,
      "format" TEXT NOT NULL,
      "title" TEXT NOT NULL,
      "author" TEXT NOT NULL,
      "file_size_bytes" INTEGER NOT NULL,
      "file_last_modified" INTEGER NOT NULL,
      "last_opened_at" INTEGER NULL,
      "imported_at" INTEGER NOT NULL,
      PRIMARY KEY ("uri")
    );
  ''');
  raw.execute('''
    CREATE TABLE "book_bookmarks" (
      "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "book_uri" TEXT NOT NULL,
      "label" TEXT NOT NULL,
      "page_index" INTEGER NOT NULL,
      "scroll_fraction" REAL NOT NULL DEFAULT 0.0,
      "created_at" INTEGER NOT NULL
    );
  ''');
}
