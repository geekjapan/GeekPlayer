import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/manga/archive_inspector.dart';
import '../../../core/storage/database.dart';
import '../domain/manga_archive.dart';
import '../domain/manga_bookmark.dart';
import '../domain/manga_locator.dart';
import '../domain/manga_metadata.dart' as domain;
import '../domain/manga_page.dart';
import '../domain/manga_repository.dart';

/// Maps a [MangaMetadataRow] to the domain [domain.MangaMetadata].
domain.MangaMetadata _rowToMeta(MangaMetadataRow row) {
  return domain.MangaMetadata(
    uri: row.uri,
    path: row.path,
    format: row.format,
    title: row.title,
    fileSizeBytes: row.fileSizeBytes,
    fileLastModified: row.fileLastModified,
    pageCount: row.pageCount,
    coverPageIndex: row.coverPageIndex,
    importedAt: row.importedAt,
    lastOpenedAt: row.lastOpenedAt,
  );
}

/// Maps a [MangaBookmarkRow] to the domain [MangaBookmark].
MangaBookmark _rowToBookmark(MangaBookmarkRow row) {
  return MangaBookmark(
    id: row.id,
    mangaUri: row.mangaUri,
    label: row.label,
    locator: MangaLocator(pageIndex: row.pageIndex),
    createdAt: row.createdAt,
  );
}

/// Concrete [MangaRepository] implementation backed by drift DAOs.
///
/// Error mapping (design.md D4 / spec error-domain):
/// - Missing file    → [FileNotFoundError]
/// - Bad extension   → [UnsupportedFormatError]
/// - No image pages  → [UnsupportedFormatError]
/// - Corrupt archive → [UnknownError]
/// - DB error        → [StorageQuotaError] (disk full) or [UnknownError]
class MangaRepositoryImpl implements MangaRepository {
  MangaRepositoryImpl({
    required this.metadataDao,
    required this.bookmarksDao,
    required this.recentItemsDao,
    ArchiveInspector? inspector,
  }) : _inspector = inspector ?? const ArchiveInspector();

  final MangaMetadataDao metadataDao;
  final MangaBookmarksDao bookmarksDao;
  final RecentItemsDao recentItemsDao;
  final ArchiveInspector _inspector;

  @override
  Future<MangaArchive> openArchive(String filePath) async {
    // Archive inspection handles FileNotFoundError + UnsupportedFormatError.
    final MangaArchiveInfo info = await _inspector.inspect(filePath);

    final String uri = Uri.file(filePath).toString();
    final File file = File(filePath);
    final FileStat stat = file.statSync();
    final String title = p.basenameWithoutExtension(filePath);
    final String ext = p
        .extension(filePath)
        .replaceFirst('.', '')
        .toLowerCase();
    final DateTime now = DateTime.now().toUtc();

    final List<MangaPage> pages = <MangaPage>[
      for (int i = 0; i < info.pages.length; i++)
        MangaPage(index: i, entryName: info.pages[i].name),
    ];

    try {
      await metadataDao.upsert(
        uri: uri,
        path: filePath,
        format: ext,
        title: title,
        fileSizeBytes: stat.size,
        fileLastModified: stat.modified.toUtc(),
        pageCount: pages.length,
        coverPageIndex: 0,
        lastOpenedAt: now,
        importedAt: now,
      );
      await recentItemsDao.recordOpen(uri, 'manga');
    } on StorageQuotaError {
      rethrow;
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }

    return MangaArchive(
      uri: uri,
      path: filePath,
      title: title,
      format: ext,
      pageCount: pages.length,
      pages: pages,
      coverPageIndex: 0,
    );
  }

  @override
  Future<List<domain.MangaMetadata>> listRecentManga() async {
    try {
      final List<MangaMetadataRow> rows = await metadataDao.listAll();
      return rows.map(_rowToMeta).toList();
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<void> saveProgress(String mangaUri, MangaLocator locator) async {
    try {
      await metadataDao.touchLastOpened(mangaUri, DateTime.now().toUtc());
      // Progress is stored as a reserved '__progress' bookmark.
      final List<MangaBookmarkRow> existing = await bookmarksDao.listByManga(
        mangaUri,
      );
      for (final MangaBookmarkRow row in existing) {
        if (row.label == '__progress') {
          await bookmarksDao.deleteById(row.id);
        }
      }
      await bookmarksDao.addBookmark(
        mangaUri: mangaUri,
        label: '__progress',
        pageIndex: locator.pageIndex,
        createdAt: DateTime.now().toUtc(),
      );
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<MangaLocator> loadProgress(String mangaUri) async {
    try {
      final List<MangaBookmarkRow> rows = await bookmarksDao.listByManga(
        mangaUri,
      );
      final MangaBookmarkRow? progress = rows
          .where((MangaBookmarkRow r) => r.label == '__progress')
          .firstOrNull;
      if (progress == null) return const MangaLocator();
      return MangaLocator(pageIndex: progress.pageIndex);
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<MangaBookmark> addBookmark({
    required String mangaUri,
    required String label,
    required MangaLocator locator,
  }) async {
    try {
      final int id = await bookmarksDao.addBookmark(
        mangaUri: mangaUri,
        label: label,
        pageIndex: locator.pageIndex,
        createdAt: DateTime.now().toUtc(),
      );
      return MangaBookmark(
        id: id,
        mangaUri: mangaUri,
        label: label,
        locator: locator,
        createdAt: DateTime.now().toUtc(),
      );
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<List<MangaBookmark>> listBookmarks(String mangaUri) async {
    try {
      final List<MangaBookmarkRow> rows = await bookmarksDao.listByManga(
        mangaUri,
      );
      return rows
          .where((MangaBookmarkRow r) => r.label != '__progress')
          .map(_rowToBookmark)
          .toList();
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<void> deleteBookmark(int id) async {
    try {
      await bookmarksDao.deleteById(id);
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<void> deleteManga(String mangaUri) async {
    try {
      await metadataDao.deleteManga(mangaUri);
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }
}
