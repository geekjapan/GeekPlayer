import 'book_locator.dart';
import 'book_metadata.dart';

/// Abstract interface for a loaded book document (PDF or EPUB).
///
/// Concrete adapters ([PdfDocument], [EpubDocument]) implement this interface
/// so the reader screen can navigate books without knowing the format.
///
/// Design decision D1: PDF and EPUB rendering is split behind this common
/// interface. The reader controller works exclusively through [BookDocument].
abstract class BookDocument {
  /// The metadata record for this book (title, author, format, uri…).
  BookMetadata get metadata;

  /// Total page count (PDF) or chapter count (EPUB).
  /// Returns `0` before the document has finished loading.
  int get pageCount;

  /// Current reading position. Updated after [goToPage] and [updateScrollFraction].
  BookLocator get currentLocator;

  /// Jump to [pageIndex] (1-based). Clamps to `[1, pageCount]`.
  /// Emits a new [currentLocator] with `scrollFraction == 0.0`.
  Future<void> goToPage(int pageIndex);

  /// Update scroll fraction within the current page/chapter.
  /// [fraction] must be in `[0.0, 1.0]`.
  Future<void> updateScrollFraction(double fraction);

  /// Release any native / IO resources held by the document.
  Future<void> dispose();
}
