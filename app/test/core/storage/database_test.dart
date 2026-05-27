import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';

void main() {
  group('AppDatabase migration', () {
    test(
      'onCreate creates playback_positions and recent_items tables',
      () async {
        final AppDatabase db = AppDatabase.forTesting(
          DatabaseConnection(NativeDatabase.memory()),
        );
        addTearDown(db.close);
        // Touching DAOs forces table access; would throw if migration missed.
        await db.playbackPositionsDao.getByUri('file:///nonexistent');
        final List<dynamic> recents = await db.recentItemsDao.list();
        expect(recents, isEmpty);
        // v2 — `add-online-novel-library` bumped from 1.
        expect(db.schemaVersion, 2);
      },
    );
  });

  group('PlaybackPositionsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    });

    tearDown(() => db.close());

    test('returns null when no row exists', () async {
      final Duration? p = await db.playbackPositionsDao.getByUri(
        'file:///x.mp4',
      );
      expect(p, isNull);
    });

    test('upsert inserts then updates on conflict', () async {
      await db.playbackPositionsDao.upsert(
        'file:///a.mp4',
        const Duration(seconds: 30),
      );
      expect(
        await db.playbackPositionsDao.getByUri('file:///a.mp4'),
        const Duration(seconds: 30),
      );
      await db.playbackPositionsDao.upsert(
        'file:///a.mp4',
        const Duration(seconds: 75),
      );
      expect(
        await db.playbackPositionsDao.getByUri('file:///a.mp4'),
        const Duration(seconds: 75),
      );
    });

    test('deleteByUri removes the row', () async {
      await db.playbackPositionsDao.upsert(
        'file:///b.mp4',
        const Duration(seconds: 10),
      );
      final int n = await db.playbackPositionsDao.deleteByUri('file:///b.mp4');
      expect(n, 1);
      expect(await db.playbackPositionsDao.getByUri('file:///b.mp4'), isNull);
    });
  });

  group('RecentItemsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    });

    tearDown(() => db.close());

    test('list is empty initially', () async {
      expect(await db.recentItemsDao.list(), isEmpty);
    });

    test('recordOpen inserts a new row', () async {
      await db.recentItemsDao.recordOpen('file:///a.mp4', 'video');
      final List<dynamic> rows = await db.recentItemsDao.list();
      expect(rows.length, 1);
    });

    test('re-opening the same URI bumps it to the top', () async {
      await db.recentItemsDao.recordOpen('file:///a.mp4', 'video');
      // ensure clock progresses
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.recentItemsDao.recordOpen('file:///b.mp4', 'video');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.recentItemsDao.recordOpen('file:///a.mp4', 'video');
      final List<dynamic> rows = await db.recentItemsDao.list();
      expect(rows.length, 2);
      expect((rows.first as dynamic).uri, 'file:///a.mp4');
    });

    test('cap at 50 entries prunes oldest', () async {
      for (int i = 0; i < 55; i++) {
        await db.recentItemsDao.recordOpen('file:///f$i.mp4', 'video');
        // ensure strictly increasing openedAt timestamps so pruning order
        // is deterministic on hosts with coarse clocks.
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final List<dynamic> rows = await db.recentItemsDao.list(limit: 100);
      expect(rows.length, 50);
      // The 5 oldest (f0..f4) should have been pruned.
      final List<String> uris = rows
          .map((dynamic r) => (r as dynamic).uri as String)
          .toList();
      for (int i = 0; i < 5; i++) {
        expect(
          uris.contains('file:///f$i.mp4'),
          isFalse,
          reason: 'file:///f$i.mp4 should have been pruned',
        );
      }
      for (int i = 5; i < 55; i++) {
        expect(
          uris.contains('file:///f$i.mp4'),
          isTrue,
          reason: 'file:///f$i.mp4 should still be present',
        );
      }
    });

    test('deleteByUri removes the row', () async {
      await db.recentItemsDao.recordOpen('file:///gone.mp4', 'video');
      final int n = await db.recentItemsDao.deleteByUri('file:///gone.mp4');
      expect(n, 1);
      expect(await db.recentItemsDao.list(), isEmpty);
    });

    test('fetchByKind filters and respects limit', () async {
      await db.recentItemsDao.recordOpen('file:///v.mp4', 'video');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await db.recentItemsDao.recordOpen('file:///a.mp3', 'audio');
      final List<dynamic> audios = await db.recentItemsDao.fetchByKind('audio');
      expect(audios.length, 1);
      expect((audios.first as dynamic).uri, 'file:///a.mp3');
    });

    test(
      'cap at 50 audio entries does NOT prune video entries (per-kind cap)',
      () async {
        // Seed 5 video entries.
        for (int i = 0; i < 5; i++) {
          await db.recentItemsDao.recordOpen('file:///v$i.mp4', 'video');
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        // Open 55 audio entries — the audio cap should kick in at 50,
        // pruning 5 audios, but leaving every video intact.
        for (int i = 0; i < 55; i++) {
          await db.recentItemsDao.recordOpen('file:///a$i.mp3', 'audio');
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        final List<dynamic> audios = await db.recentItemsDao.fetchByKind(
          'audio',
          limit: 100,
        );
        expect(audios.length, 50);
        final List<dynamic> videos = await db.recentItemsDao.fetchByKind(
          'video',
          limit: 100,
        );
        expect(videos.length, 5);
      },
    );
  });
}
