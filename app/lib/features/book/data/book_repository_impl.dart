import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/storage/database.dart';
import '../domain/book_bookmark.dart';
import '../domain/book_document.dart';
import '../domain/book_format.dart';
import '../domain/book_locator.dart';
import '../domain/book_metadata.dart' as domain;
import '../domain/book_repository.dart';
import 'epub_document.dart';
import 'pdf_document.dart';

/// Maps a [BookMetadataRow] to the domain [domain.BookMetadata].
domain.BookMetadata _rowToMeta(BookMetadataRow row) {
  return domain.BookMetadata(
    uri: row.uri,
    path: row.path,
    format: BookFormat.fromExtension(row.format) ?? BookFormat.pdf,
    title: row.title,
    author: row.author,
    fileSizeBytes: row.fileSizeBytes,
    fileLastModified: row.fileLastModified,
    lastOpenedAt: row.lastOpenedAt,
    importedAt: row.importedAt,
  );
}

/// Maps a [BookBookmarkRow] to the domain [BookBookmark].
BookBookmark _rowToBookmark(BookBookmarkRow row) {
  return BookBookmark(
    id: row.id,
    bookUri: row.bookUri,
    label: row.label,
    locator: BookLocator(
      pageIndex: row.pageIndex,
      scrollFraction: row.scrollFraction,
    ),
    createdAt: row.createdAt,
  );
}

/// Concrete [BookRepository] implementation backed by drift DAOs.
///
/// Error mapping (design.md D5 / task 3.5):
/// - Missing file  → [FileNotFoundError]
/// - Bad extension → [UnsupportedFormatError]
/// - Parse error   → [UnknownError]
/// - DB error      → [StorageQuotaError] (disk full) or [UnknownError]
class BookRepositoryImpl implements BookRepository {
  BookRepositoryImpl({
    required this.metadataDao,
    required this.bookmarksDao,
    required this.recentItemsDao,
  });

  final BookMetadataDao metadataDao;
  final BookBookmarksDao bookmarksDao;
  final RecentItemsDao recentItemsDao;

  @override
  Future<BookDocument> openBook(String filePath) async {
    final File file = File(filePath);
    if (!file.existsSync()) {
      throw FileNotFoundError(
        message: 'File not found: $filePath',
        uri: Uri.file(filePath),
      );
    }

    final String ext = p.extension(filePath).replaceFirst('.', '');
    final BookFormat? format = BookFormat.fromExtension(ext);
    if (format == null) {
      throw UnsupportedFormatError(
        message: 'Unsupported book format: .$ext',
        extension: ext,
      );
    }

    final String uri = Uri.file(filePath).toString();
    final FileStat stat = file.statSync();

    // Upsert metadata so the book appears in recent list.
    String title = p.basenameWithoutExtension(filePath);
    String author = '';

    // Try to open document first to get actual metadata.
    BookDocument doc;
    try {
      final domain.BookMetadata tempMeta = domain.BookMetadata(
        uri: uri,
        path: filePath,
        format: format,
        title: title,
        author: author,
        fileSizeBytes: stat.size,
        fileLastModified: stat.modified.toUtc(),
        importedAt: DateTime.now().toUtc(),
      );

      if (format == BookFormat.pdf) {
        doc = await PdfBookDocument.open(filePath, tempMeta);
        // pdfrx doesn't expose author/title via PdfDocument directly in all
        // versions; use filename as title for now.
      } else {
        doc = await EpubBookDocument.open(filePath, tempMeta);
      }
    } on FileNotFoundError {
      rethrow;
    } on UnsupportedFormatError {
      rethrow;
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }

    final DateTime now = DateTime.now().toUtc();

    try {
      await metadataDao.upsert(
        uri: uri,
        path: filePath,
        format: format.code,
        title: title,
        author: author,
        fileSizeBytes: stat.size,
        fileLastModified: stat.modified.toUtc(),
        lastOpenedAt: now,
        importedAt: now,
      );
      await recentItemsDao.recordOpen(uri, 'book');
    } on StorageQuotaError {
      rethrow;
    } catch (e, st) {
      // Storage errors are non-fatal for opening; the doc is already in memory.
      // Wrap as UnknownError so callers can log it.
      throw UnknownError(e, stackTrace: st);
    }

    return doc;
  }

  @override
  Future<List<domain.BookMetadata>> listRecentBooks() async {
    try {
      final List<BookMetadataRow> rows = await metadataDao.listAll();
      return rows.map(_rowToMeta).toList();
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<void> saveProgress(String bookUri, BookLocator locator) async {
    try {
      await metadataDao.touchLastOpened(bookUri, DateTime.now().toUtc());
      // Progress is stored as a bookmark with a reserved label.
      // We upsert by deleting and re-inserting the '__progress' bookmark.
      final List<BookBookmarkRow> existing = await bookmarksDao.listByBook(
        bookUri,
      );
      for (final BookBookmarkRow row in existing) {
        if (row.label == '__progress') {
          await bookmarksDao.deleteById(row.id);
        }
      }
      await bookmarksDao.addBookmark(
        bookUri: bookUri,
        label: '__progress',
        pageIndex: locator.pageIndex,
        scrollFraction: locator.scrollFraction,
        createdAt: DateTime.now().toUtc(),
      );
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<BookLocator> loadProgress(String bookUri) async {
    try {
      final List<BookBookmarkRow> rows = await bookmarksDao.listByBook(bookUri);
      final BookBookmarkRow? progress = rows
          .where((BookBookmarkRow r) => r.label == '__progress')
          .firstOrNull;
      if (progress == null) return const BookLocator(pageIndex: 1);
      return BookLocator(
        pageIndex: progress.pageIndex,
        scrollFraction: progress.scrollFraction,
      );
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<BookBookmark> addBookmark({
    required String bookUri,
    required String label,
    required BookLocator locator,
  }) async {
    try {
      final int id = await bookmarksDao.addBookmark(
        bookUri: bookUri,
        label: label,
        pageIndex: locator.pageIndex,
        scrollFraction: locator.scrollFraction,
        createdAt: DateTime.now().toUtc(),
      );
      return BookBookmark(
        id: id,
        bookUri: bookUri,
        label: label,
        locator: locator,
        createdAt: DateTime.now().toUtc(),
      );
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }

  @override
  Future<List<BookBookmark>> listBookmarks(String bookUri) async {
    try {
      final List<BookBookmarkRow> rows = await bookmarksDao.listByBook(bookUri);
      return rows
          .where((BookBookmarkRow r) => r.label != '__progress')
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
  Future<void> deleteBook(String bookUri) async {
    try {
      await metadataDao.deleteBook(bookUri);
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }
  }
}
