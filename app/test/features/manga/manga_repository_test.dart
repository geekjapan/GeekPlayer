import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/manga/data/manga_repository_impl.dart';
import 'package:geekplayer/features/manga/domain/manga_locator.dart';

/// Tests covering tasks 7.3, 7.4, 7.5: repository persistence,
/// bookmarks, and reading resume.
void main() {
  late AppDatabase db;
  late MangaRepositoryImpl repo;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repo = MangaRepositoryImpl(
      metadataDao: db.mangaMetadataDao,
      bookmarksDao: db.mangaBookmarksDao,
      recentItemsDao: db.recentItemsDao,
    );
    tempDir = await Directory.systemTemp.createTemp('manga_repo_test_');
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Write a minimal valid CBZ file with [pageCount] pages into [tempDir].
  File writeCbz(String name, {int pageCount = 3}) {
    final Archive archive = Archive();
    final List<int> pngBytes = _minimalPng();
    for (int i = 1; i <= pageCount; i++) {
      archive.addFile(ArchiveFile('$i.jpg', pngBytes.length, pngBytes));
    }
    final List<int> bytes = ZipEncoder().encode(archive);
    final File f = File('${tempDir.path}/$name');
    f.writeAsBytesSync(bytes);
    return f;
  }

  // ---------------------------------------------------------------------------
  // Task 7.3: Metadata persistence and recent ordering
  // ---------------------------------------------------------------------------

  group('openArchive', () {
    test('persists metadata on first open', () async {
      final File cbz = writeCbz('manga1.cbz');
      final archive = await repo.openArchive(cbz.path);

      expect(archive.pageCount, 3);
      expect(archive.format, 'cbz');

      final recent = await repo.listRecentManga();
      expect(recent.length, 1);
      expect(recent.first.uri, Uri.file(cbz.path).toString());
    });

    test('upserts on second open — no duplicate', () async {
      final File cbz = writeCbz('manga2.cbz');
      await repo.openArchive(cbz.path);
      await repo.openArchive(cbz.path);

      final recent = await repo.listRecentManga();
      expect(recent.length, 1);
    });

    test('most recently opened appears first in listRecentManga', () async {
      final File a = writeCbz('a.cbz');
      final File b = writeCbz('b.cbz');
      await repo.openArchive(a.path);
      await repo.openArchive(b.path);

      // Set an explicitly later lastOpenedAt on b to guarantee ordering
      // independent of drift's datetime resolution (stored as unix seconds).
      final String bUri = Uri.file(b.path).toString();
      await db.mangaMetadataDao.touchLastOpened(bUri, DateTime.utc(2030, 1, 1));

      final recent = await repo.listRecentManga();
      expect(recent.first.path, b.path);
    });

    test('records "manga" kind in recent_items', () async {
      final File cbz = writeCbz('recent.cbz');
      await repo.openArchive(cbz.path);

      final items = await db.recentItemsDao.fetchByKind('manga');
      expect(items.length, 1);
      expect(items.first.kind, 'manga');
    });

    test('throws FileNotFoundError for missing file', () {
      expect(
        () => repo.openArchive('/no/such/file.cbz'),
        throwsA(isA<FileNotFoundError>()),
      );
    });

    test('throws UnsupportedFormatError for .rar extension', () async {
      final File rar = File('${tempDir.path}/test.rar')
        ..writeAsBytesSync(<int>[0xDE, 0xAD]);
      expect(
        () => repo.openArchive(rar.path),
        throwsA(isA<UnsupportedFormatError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Task 7.4: Bookmark persistence
  // ---------------------------------------------------------------------------

  group('bookmark operations', () {
    test('addBookmark / listBookmarks / deleteBookmark round-trip', () async {
      final File cbz = writeCbz('bm.cbz');
      final archive = await repo.openArchive(cbz.path);

      final bm = await repo.addBookmark(
        mangaUri: archive.uri,
        label: 'Great scene',
        locator: const MangaLocator(pageIndex: 7),
      );
      expect(bm.locator.pageIndex, 7);

      final marks = await repo.listBookmarks(archive.uri);
      expect(marks.length, 1);
      expect(marks.first.label, 'Great scene');

      await repo.deleteBookmark(bm.id);
      expect(await repo.listBookmarks(archive.uri), isEmpty);
    });

    test('bookmark survives repo reconstruction (persisted in DB)', () async {
      final File cbz = writeCbz('persist.cbz');
      final archive = await repo.openArchive(cbz.path);
      await repo.addBookmark(
        mangaUri: archive.uri,
        label: 'p8',
        locator: const MangaLocator(pageIndex: 8),
      );

      // Simulate restart by creating a new repo instance against the same DB.
      final repo2 = MangaRepositoryImpl(
        metadataDao: db.mangaMetadataDao,
        bookmarksDao: db.mangaBookmarksDao,
        recentItemsDao: db.recentItemsDao,
      );
      final marks = await repo2.listBookmarks(archive.uri);
      expect(marks.length, 1);
      expect(marks.first.locator.pageIndex, 8);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 7.5: Reader resume (page index and spread anchor)
  // ---------------------------------------------------------------------------

  group('saveProgress / loadProgress', () {
    test('defaults to page 0 when no progress saved', () async {
      final File cbz = writeCbz('fresh.cbz');
      final archive = await repo.openArchive(cbz.path);
      final locator = await repo.loadProgress(archive.uri);
      expect(locator.pageIndex, 0);
    });

    test('saveProgress persists and loadProgress restores', () async {
      final File cbz = writeCbz('resume.cbz');
      final archive = await repo.openArchive(cbz.path);
      await repo.saveProgress(archive.uri, const MangaLocator(pageIndex: 23));

      final locator = await repo.loadProgress(archive.uri);
      expect(locator.pageIndex, 23);
    });

    test('saveProgress overwrites previous position', () async {
      final File cbz = writeCbz('overwrite.cbz');
      final archive = await repo.openArchive(cbz.path);
      await repo.saveProgress(archive.uri, const MangaLocator(pageIndex: 5));
      await repo.saveProgress(archive.uri, const MangaLocator(pageIndex: 42));

      final locator = await repo.loadProgress(archive.uri);
      expect(locator.pageIndex, 42);
    });

    test('saveProgress does not pollute user-visible bookmark list', () async {
      final File cbz = writeCbz('no_progress_bm.cbz');
      final archive = await repo.openArchive(cbz.path);
      await repo.saveProgress(archive.uri, const MangaLocator(pageIndex: 10));
      await repo.addBookmark(
        mangaUri: archive.uri,
        label: 'User mark',
        locator: const MangaLocator(pageIndex: 3),
      );

      // listBookmarks must NOT return the internal __progress entry.
      final marks = await repo.listBookmarks(archive.uri);
      expect(marks.length, 1);
      expect(marks.first.label, 'User mark');
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal PNG
// ---------------------------------------------------------------------------

List<int> _minimalPng() => <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x90,
  0x77,
  0x53,
  0xDE,
  0x00,
  0x00,
  0x00,
  0x0C,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xDC,
  0xCC,
  0x59,
  0xE7,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
