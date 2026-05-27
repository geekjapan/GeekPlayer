import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/audio/data/audio_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late AudioRepository repo;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repo = AudioRepository(
      positionsDao: db.playbackPositionsDao,
      recentItemsDao: db.recentItemsDao,
    );
    tempDir = await Directory.systemTemp.createTemp('geekplayer_audio_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('expandFolderToQueue returns null when folder is empty', () async {
    final AudioPickResult? r = await repo.expandFolderToQueue(tempDir.path);
    expect(r, isNull);
  });

  test(
    'expandFolderToQueue filters to supported extensions, sorts ascending',
    () async {
      // Create 5 files: 3 supported audio + 1 video + 1 text.
      for (final String name in <String>[
        'b.mp3',
        'a.flac',
        'c.opus',
        'd.mp4', // not audio
        'e.txt', // not audio
      ]) {
        await File(p.join(tempDir.path, name)).create();
      }
      final AudioPickResult? r = await repo.expandFolderToQueue(tempDir.path);
      expect(r, isNotNull);
      expect(r!.tracks.length, 3);
      expect(r.tracks.map((t) => t.displayName).toList(), <String>[
        'a.flac',
        'b.mp3',
        'c.opus',
      ]);
      expect(r.sourceUri.toFilePath(), p.normalize(tempDir.path) + p.separator);
    },
  );

  test('fetchRecentAudioItems only returns audio rows', () async {
    await repo.recordRecentOpen(Uri.parse('file:///x.mp3'));
    // Manually insert a video row to make sure it doesn't bleed across.
    await db.recentItemsDao.recordOpen('file:///y.mp4', 'video');
    final list = await repo.fetchRecentAudioItems();
    expect(list.length, 1);
    expect(list.first.uri.toString(), 'file:///x.mp3');
  });

  test('sourceExists returns true for an existing file URI', () async {
    final File f = await File(p.join(tempDir.path, 'a.mp3')).create();
    final exists = await repo.sourceExists(Uri.file(f.path));
    expect(exists, isTrue);
  });

  test('sourceExists returns false for a missing path', () async {
    final exists = await repo.sourceExists(
      Uri.file(p.join(tempDir.path, 'missing.mp3')),
    );
    expect(exists, isFalse);
  });

  test('sourceExists handles directory URIs', () async {
    final exists = await repo.sourceExists(Uri.directory(tempDir.path));
    expect(exists, isTrue);
  });
}
