import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// drift v2 -> v3 and v1 -> v3 skip migration tests
/// (CONVENTIONS.md §5; spec `settings-persistence` Requirement
/// "drift schema version reaches 3 via additive migrations").
///
/// Mirrors the structure of `migration_v1_to_v2_test.dart`: hand-roll the
/// older schema in an in-memory sqlite3, seed rows, open [AppDatabase]
/// (schema v3) against the same connection so drift's migrator fires.
/// After migration, every pre-existing row MUST survive and `app_settings`
/// MUST be present and empty.
void main() {
  group('migration v2 -> v3', () {
    test('creates app_settings and preserves novel/playback data', () async {
      final Database raw = sqlite3.openInMemory();
      _createV1Schema(raw);
      _createV2Schema(raw);
      raw.execute('PRAGMA user_version = 2;');

      // Seed v1 + v2 data so we can prove additive migration.
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
          'synopsis here',
          5,
          DateTime.utc(2026, 5, 10).millisecondsSinceEpoch,
          null,
        ],
      );
      raw.execute(
        'INSERT INTO "novel_episodes" VALUES (?, ?, ?, ?, ?, ?)',
        <Object>[
          'narou',
          'n1234ab',
          1,
          'Episode One',
          'body text',
          DateTime.utc(2026, 5, 10).millisecondsSinceEpoch,
        ],
      );
      raw.execute('INSERT INTO "site_consents" VALUES (?, ?, ?, ?)', <Object>[
        'narou',
        1,
        DateTime.utc(2026, 5, 10).millisecondsSinceEpoch,
        '2026-05-27',
      ]);

      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.opened(raw)),
      );
      addTearDown(db.close);

      // Force migration by touching the new DAO.
      final List<AppSettingRow> settings = await db.appSettingsDao.getAll();
      expect(settings, isEmpty);

      // v1 rows survive.
      expect(
        await db.playbackPositionsDao.getByUri('file:///movie.mp4'),
        const Duration(milliseconds: 45000),
      );
      final recents = await db.recentItemsDao.list();
      expect(recents.length, 1);
      expect(recents.first.uri, 'file:///movie.mp4');

      // v2 rows survive.
      final works = await db.novelWorksDao.listAll();
      expect(works.length, 1);
      expect(works.first.title, 'Sample Title');
      final episodes = await db.novelEpisodesDao.listEpisodes(
        'narou',
        'n1234ab',
      );
      expect(episodes.length, 1);
      expect(episodes.first.title, 'Episode One');
      expect((await db.siteConsentsDao.getAll()).length, 1);

      // user_version updated to 3.
      final ResultSet versionRow = raw.select('PRAGMA user_version');
      expect(versionRow.first.values.first, 3);
    });
  });

  group('migration v1 -> v3 (skip)', () {
    test(
      'runs both branches and preserves playback/recent data; novel_* + app_settings exist',
      () async {
        final Database raw = sqlite3.openInMemory();
        _createV1Schema(raw);
        raw.execute('PRAGMA user_version = 1;');

        raw.execute(
          'INSERT INTO "playback_positions" VALUES (?, ?, ?)',
          <Object>[
            'file:///audio.mp3',
            12000,
            DateTime.utc(2026, 4, 1).millisecondsSinceEpoch,
          ],
        );
        raw.execute('INSERT INTO "recent_items" VALUES (?, ?, ?)', <Object>[
          'file:///audio.mp3',
          'audio',
          DateTime.utc(2026, 4, 1).millisecondsSinceEpoch,
        ]);

        final AppDatabase db = AppDatabase.forTesting(
          DatabaseConnection(NativeDatabase.opened(raw)),
        );
        addTearDown(db.close);

        // Touch every new DAO to confirm the tables exist.
        expect(await db.appSettingsDao.getAll(), isEmpty);
        expect(await db.novelWorksDao.listAll(), isEmpty);
        expect(
          await db.novelEpisodesDao.existingIndices('narou', 'x'),
          isEmpty,
        );
        expect(await db.novelBookmarksDao.getBookmark('narou', 'x'), isNull);
        expect(await db.siteConsentsDao.getAll(), isEmpty);

        // v1 rows survive across the skip.
        expect(
          await db.playbackPositionsDao.getByUri('file:///audio.mp3'),
          const Duration(milliseconds: 12000),
        );
        final recents = await db.recentItemsDao.list();
        expect(recents.length, 1);
        expect(recents.first.uri, 'file:///audio.mp3');

        // user_version updated to 3.
        final ResultSet versionRow = raw.select('PRAGMA user_version');
        expect(versionRow.first.values.first, 3);
      },
    );
  });

  group('fresh install (onCreate)', () {
    test('schemaVersion is 3 and app_settings is empty', () async {
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(db.close);

      expect(db.schemaVersion, 3);
      // Touching DAOs triggers onCreate.
      expect(await db.appSettingsDao.getAll(), isEmpty);
      expect(await db.playbackPositionsDao.getByUri('x'), isNull);
      expect(await db.novelWorksDao.listAll(), isEmpty);
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
