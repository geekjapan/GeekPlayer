import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// drift v1 -> v2 migration test (CONVENTIONS.md §5 requirement).
///
/// We bootstrap a sqlite3 in-memory DB with the v1 schema by hand
/// (`playback_positions` + `recent_items` + `schema_version = 1`),
/// seed it with some rows, then open the current [AppDatabase] against
/// the same connection. drift's `onUpgrade` should fire and create the
/// four v2 tables additively while leaving v1 rows intact.
void main() {
  test(
    'v1 -> v2 onUpgrade creates novel_* tables and preserves data',
    () async {
      final Database raw = sqlite3.openInMemory();

      // Hand-roll the v1 schema. Column types/names mirror
      // tables/playback_positions.dart and tables/recent_items.dart.
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
      // drift stores its current schema version in `PRAGMA user_version`.
      raw.execute('PRAGMA user_version = 1;');

      // Seed v1 data.
      raw.execute('INSERT INTO "playback_positions" VALUES (?, ?, ?)', <Object>[
        'file:///a.mp4',
        90000,
        DateTime.utc(2026, 5, 1).millisecondsSinceEpoch,
      ]);
      raw.execute('INSERT INTO "recent_items" VALUES (?, ?, ?)', <Object>[
        'file:///a.mp4',
        'video',
        DateTime.utc(2026, 5, 1).millisecondsSinceEpoch,
      ]);

      // Open AppDatabase against the same connection. NativeDatabase.opened
      // wraps a pre-existing sqlite3 handle so drift's migrator runs against
      // our hand-rolled v1 DB.
      final AppDatabase db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.opened(raw)),
      );
      addTearDown(db.close);

      // Force the migrator to run by touching any DAO. drift defers
      // migration to the first executor call.
      final List<NovelWorkRow> works = await db.novelWorksDao.listAll();
      expect(works, isEmpty);

      // v1 data must survive.
      final Duration? pos = await db.playbackPositionsDao.getByUri(
        'file:///a.mp4',
      );
      expect(pos, const Duration(milliseconds: 90000));

      final List<RecentItemRow> recents = await db.recentItemsDao.list();
      expect(recents.length, 1);
      expect(recents.first.uri, 'file:///a.mp4');

      // All four new v2 tables must be present and queryable.
      expect(await db.novelEpisodesDao.existingIndices('narou', 'x'), isEmpty);
      expect(await db.novelBookmarksDao.getBookmark('narou', 'x'), isNull);
      expect(await db.siteConsentsDao.getAll(), isEmpty);

      // user_version is bumped to the current AppDatabase.schemaVersion.
      // After add-app-settings (v3), v1 → v3 runs both onUpgrade
      // branches, but this test asserts only the v1 → v2 portion (novel
      // tables). The full v1 → v3 skip path is exercised by
      // migration_v2_to_v3_test.dart.
      final ResultSet versionRow = raw.select('PRAGMA user_version');
      expect(versionRow.first.values.first, 3);
    },
  );
}
