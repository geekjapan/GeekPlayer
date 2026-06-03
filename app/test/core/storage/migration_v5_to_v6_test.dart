import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// drift v5 -> v6 and v1 -> v6 skip-migration tests
/// (CONVENTIONS.md §5; add-media-library design.md D1).
///
/// Mirrors the structure of `migration_v4_to_v5_test.dart`: hand-roll the
/// v5 schema in in-memory sqlite3, seed rows, open [AppDatabase] (schema v6)
/// against the same connection so drift's migrator fires. After migration,
/// every pre-existing row MUST survive, and the five new v6 tables MUST be
/// present and empty.
void main() {
  group('migration v5 -> v6', () {
    test('creates v6 tables and preserves all v1-v5 data', () async {
      final Database raw = sqlite3.openInMemory();
      _createV1Schema(raw);
      _createV2Schema(raw);
      _createV3Schema(raw);
      _createV4Schema(raw);
      _createV5Schema(raw);
      raw.execute('PRAGMA user_version = 5;');

      // Seed rows across all prior versions.
      raw.execute('INSERT INTO "playback_positions" VALUES (?, ?, ?)', <Object>[
        'file:///movie.mp4',
        45000,
        DateTime.utc(2026, 5, 1).millisecondsSinceEpoch,
      ]);
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
      raw.execute(
        'INSERT INTO "manga_metadata" VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'file:///manga.cbz',
          '/manga.cbz',
          'cbz',
          'Test Manga',
          2048,
          DateTime.utc(2026, 5, 20).millisecondsSinceEpoch,
          30,
          null,
          DateTime.utc(2026, 5, 20).millisecondsSinceEpoch,
          null,
        ],
      );

      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.opened(raw)),
      );
      addTearDown(db.close);

      // Touch v6 DAOs to trigger migration.
      expect(await db.mediaIndexDao.listAll(), isEmpty);
      expect(await db.watchHistoryDao.listRecent(), isEmpty);
      expect(await db.favoritesDao.listAll(), isEmpty);
      expect(await db.playlistsDao.listAll(), isEmpty);
      expect(await db.playlistItemsDao.listByPlaylist(0), isEmpty);

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

      // v5 rows survive.
      final MangaMetadataRow? manga = await db.mangaMetadataDao.getByUri(
        'file:///manga.cbz',
      );
      expect(manga, isNotNull);
      expect(manga!.title, 'Test Manga');

      // user_version updated to 6.
      final ResultSet versionRow = raw.select('PRAGMA user_version');
      expect(versionRow.first.values.first, 6);
    });
  });

  group('migration v1 -> v6 (skip)', () {
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

      expect(await db.mediaIndexDao.listAll(), isEmpty);
      expect(await db.watchHistoryDao.listRecent(), isEmpty);
      expect(await db.favoritesDao.listAll(), isEmpty);
      expect(await db.playlistsDao.listAll(), isEmpty);
      expect(await db.mangaMetadataDao.listAll(), isEmpty);
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
    test('schemaVersion is 6 and all v6 tables are empty', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      expect(db.schemaVersion, 6);
      expect(await db.mediaIndexDao.listAll(), isEmpty);
      expect(await db.watchHistoryDao.listRecent(), isEmpty);
      expect(await db.favoritesDao.listAll(), isEmpty);
      expect(await db.playlistsDao.listAll(), isEmpty);
      expect(await db.playbackPositionsDao.getByUri('x'), isNull);
    });
  });

  group('MediaIndexDao', () {
    test('upsert and getByUri round-trip', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime now = DateTime.utc(2026, 6, 1);
      await db.mediaIndexDao.upsert(
        uri: 'file:///video.mp4',
        path: '/video.mp4',
        kind: 'video',
        title: 'Sample Video',
        extension: 'mp4',
        fileSizeBytes: 10240,
        fileLastModified: now,
        scannedAt: now,
      );

      final MediaIndexRow? row = await db.mediaIndexDao.getByUri(
        'file:///video.mp4',
      );
      expect(row, isNotNull);
      expect(row!.title, 'Sample Video');
      expect(row.kind, 'video');
      expect(row.extension, 'mp4');
    });

    test('upsert is idempotent — second call updates, no duplicate', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      await db.mediaIndexDao.upsert(
        uri: 'file:///audio.mp3',
        path: '/audio.mp3',
        kind: 'audio',
        title: 'Old Title',
        extension: 'mp3',
        fileSizeBytes: 100,
        fileLastModified: t,
        scannedAt: t,
      );
      await db.mediaIndexDao.upsert(
        uri: 'file:///audio.mp3',
        path: '/audio.mp3',
        kind: 'audio',
        title: 'New Title',
        extension: 'mp3',
        fileSizeBytes: 200,
        fileLastModified: t,
        scannedAt: t,
      );

      final List<MediaIndexRow> all = await db.mediaIndexDao.listAll();
      expect(all.length, 1);
      expect(all.first.title, 'New Title');
      expect(all.first.fileSizeBytes, 200);
    });

    test('listByKind filters correctly', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      await db.mediaIndexDao.upsert(
        uri: 'file:///v.mp4',
        path: '/v.mp4',
        kind: 'video',
        title: 'Vid',
        extension: 'mp4',
        fileSizeBytes: 100,
        fileLastModified: t,
        scannedAt: t,
      );
      await db.mediaIndexDao.upsert(
        uri: 'file:///a.mp3',
        path: '/a.mp3',
        kind: 'audio',
        title: 'Aud',
        extension: 'mp3',
        fileSizeBytes: 50,
        fileLastModified: t,
        scannedAt: t,
      );

      final List<MediaIndexRow> videos = await db.mediaIndexDao.listByKind(
        'video',
      );
      expect(videos.length, 1);
      expect(videos.first.kind, 'video');

      final List<MediaIndexRow> audios = await db.mediaIndexDao.listByKind(
        'audio',
      );
      expect(audios.length, 1);
      expect(audios.first.kind, 'audio');
    });
  });

  group('WatchHistoryDao', () {
    test('upsert and getByUri round-trip', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime now = DateTime.utc(2026, 6, 1);
      await db.watchHistoryDao.upsert(
        uri: 'file:///movie.mkv',
        lastPlayedAt: now,
        positionMs: 30000,
        durationMs: 120000,
        completed: false,
      );

      final WatchHistoryRow? row = await db.watchHistoryDao.getByUri(
        'file:///movie.mkv',
      );
      expect(row, isNotNull);
      expect(row!.positionMs, 30000);
      expect(row.completed, isFalse);
    });

    test('upsert marks completed on second call', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime t = DateTime.utc(2026, 6, 1);
      const String uri = 'file:///ep1.mp4';
      await db.watchHistoryDao.upsert(
        uri: uri,
        lastPlayedAt: t,
        positionMs: 50000,
        durationMs: 60000,
        completed: false,
      );
      await db.watchHistoryDao.upsert(
        uri: uri,
        lastPlayedAt: t.add(const Duration(minutes: 1)),
        positionMs: 60000,
        durationMs: 60000,
        completed: true,
      );

      final WatchHistoryRow? row = await db.watchHistoryDao.getByUri(uri);
      expect(row!.completed, isTrue);
    });
  });

  group('FavoritesDao', () {
    test('add / isFavorite / remove round-trip', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      const String uri = 'file:///fav.mp4';
      expect(await db.favoritesDao.isFavorite(uri), isFalse);

      await db.favoritesDao.add(uri, DateTime.utc(2026, 6, 1));
      expect(await db.favoritesDao.isFavorite(uri), isTrue);

      await db.favoritesDao.remove(uri);
      expect(await db.favoritesDao.isFavorite(uri), isFalse);
    });

    test('listAll returns newest-favorited first', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      await db.favoritesDao.add('file:///a.mp4', DateTime.utc(2026, 6, 1));
      await db.favoritesDao.add('file:///b.mp4', DateTime.utc(2026, 6, 2));

      final List<FavoriteRow> all = await db.favoritesDao.listAll();
      expect(all.length, 2);
      expect(all.first.uri, 'file:///b.mp4');
    });
  });

  group('PlaylistsDao + PlaylistItemsDao', () {
    test('create, add items, list, delete cascades', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime now = DateTime.utc(2026, 6, 1);
      final int id = await db.playlistsDao.create('Workout', now);
      expect(id, greaterThan(0));

      await db.playlistItemsDao.add(
        playlistId: id,
        mediaUri: 'file:///track1.mp3',
        position: 0,
      );
      await db.playlistItemsDao.add(
        playlistId: id,
        mediaUri: 'file:///track2.mp3',
        position: 1,
      );

      final List<PlaylistItemRow> items = await db.playlistItemsDao
          .listByPlaylist(id);
      expect(items.length, 2);
      expect(items.first.mediaUri, 'file:///track1.mp3');
      expect(items.last.mediaUri, 'file:///track2.mp3');

      // Cascade delete removes items.
      await db.playlistsDao.deleteById(id);
      expect(await db.playlistsDao.getById(id), isNull);
      expect(await db.playlistItemsDao.listByPlaylist(id), isEmpty);
    });

    test('replaceAll reorders items', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      final DateTime now = DateTime.utc(2026, 6, 1);
      final int id = await db.playlistsDao.create('Mix', now);

      await db.playlistItemsDao.add(
        playlistId: id,
        mediaUri: 'file:///a.mp3',
        position: 0,
      );
      await db.playlistItemsDao.add(
        playlistId: id,
        mediaUri: 'file:///b.mp3',
        position: 1,
      );

      // Swap order.
      await db.playlistItemsDao.replaceAll(id, <String>[
        'file:///b.mp3',
        'file:///a.mp3',
      ]);

      final List<PlaylistItemRow> items = await db.playlistItemsDao
          .listByPlaylist(id);
      expect(items.first.mediaUri, 'file:///b.mp3');
      expect(items.first.position, 0);
      expect(items.last.mediaUri, 'file:///a.mp3');
      expect(items.last.position, 1);
    });
  });
}

// ---------------------------------------------------------------------------
// Schema helpers (mirrors migration_v4_to_v5_test.dart)
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

void _createV5Schema(Database raw) {
  raw.execute('''
    CREATE TABLE "manga_metadata" (
      "uri" TEXT NOT NULL,
      "path" TEXT NOT NULL,
      "format" TEXT NOT NULL,
      "title" TEXT NOT NULL,
      "file_size_bytes" INTEGER NOT NULL,
      "file_last_modified" INTEGER NOT NULL,
      "page_count" INTEGER NOT NULL,
      "cover_page_index" INTEGER NULL,
      "imported_at" INTEGER NOT NULL,
      "last_opened_at" INTEGER NULL,
      PRIMARY KEY ("uri")
    );
  ''');
  raw.execute('''
    CREATE TABLE "manga_bookmarks" (
      "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "manga_uri" TEXT NOT NULL,
      "label" TEXT NOT NULL,
      "page_index" INTEGER NOT NULL,
      "created_at" INTEGER NOT NULL
    );
  ''');
}
