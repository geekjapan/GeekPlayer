import 'book_bookmark.dart';
import 'book_document.dart';
import 'book_locator.dart';
import 'book_metadata.dart';

/// Contract for the book repository. Implemented by [BookRepositoryImpl].
///
/// Use-cases that callers need:
/// - Import a file (open picker → persist metadata → return [BookDocument]).
/// - List recently opened books.
/// - Save / restore reading progress.
/// - CRUD bookmarks.
abstract class BookRepository {
  /// Open [filePath] as a [BookDocument], persist/upsert metadata, and stamp
  /// `lastOpenedAt`. Returns the opened document.
  ///
  /// Throws:
  /// - [FileNotFoundError] if [filePath] does not exist.
  /// - [UnsupportedFormatError] if the extension is not pdf/epub.
  /// - [UnknownError] wrapping any parse failure.
  Future<BookDocument> openBook(String filePath);

  /// All books, newest-opened first.
  Future<List<BookMetadata>> listRecentBooks();

  /// Save the current reading position for [bookUri].
  Future<void> saveProgress(String bookUri, BookLocator locator);

  /// Load the last saved reading position for [bookUri], or
  /// `BookLocator(pageIndex: 1)` when no progress exists.
  Future<BookLocator> loadProgress(String bookUri);

  /// Add a named bookmark at [locator] inside [bookUri].
  /// Returns the new [BookBookmark].
  Future<BookBookmark> addBookmark({
    required String bookUri,
    required String label,
    required BookLocator locator,
  });

  /// All bookmarks for [bookUri], oldest-first.
  Future<List<BookBookmark>> listBookmarks(String bookUri);

  /// Delete the bookmark identified by [id].
  Future<void> deleteBookmark(int id);

  /// Remove book metadata and all bookmarks for [bookUri].
  Future<void> deleteBook(String bookUri);
}
