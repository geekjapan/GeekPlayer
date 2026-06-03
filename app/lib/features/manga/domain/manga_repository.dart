import 'manga_archive.dart';
import 'manga_bookmark.dart';
import 'manga_locator.dart';
import 'manga_metadata.dart';

/// Contract for the manga repository. Implemented by [MangaRepositoryImpl].
///
/// Use-cases:
/// - Open an archive file → persist metadata → return [MangaArchive].
/// - List recently opened archives.
/// - Save / restore reading progress.
/// - CRUD bookmarks.
abstract class MangaRepository {
  /// Open [filePath] as a [MangaArchive], persist/upsert metadata, and stamp
  /// `lastOpenedAt`. Returns the opened archive.
  ///
  /// Throws:
  /// - [FileNotFoundError] if [filePath] does not exist.
  /// - [UnsupportedFormatError] if the extension is not cbz/zip.
  /// - [UnsupportedFormatError] if the archive has no valid image pages.
  /// - [UnknownError] wrapping archive inspection or storage failures.
  Future<MangaArchive> openArchive(String filePath);

  /// All manga archives, newest-opened first.
  Future<List<MangaMetadata>> listRecentManga();

  /// Save the current reading position for [mangaUri].
  Future<void> saveProgress(String mangaUri, MangaLocator locator);

  /// Load the last saved reading position for [mangaUri], or
  /// `MangaLocator()` when no progress exists.
  Future<MangaLocator> loadProgress(String mangaUri);

  /// Add a named bookmark at [locator] inside [mangaUri].
  Future<MangaBookmark> addBookmark({
    required String mangaUri,
    required String label,
    required MangaLocator locator,
  });

  /// All bookmarks for [mangaUri], oldest-first.
  Future<List<MangaBookmark>> listBookmarks(String mangaUri);

  /// Delete the bookmark identified by [id].
  Future<void> deleteBookmark(int id);

  /// Remove manga metadata and all bookmarks for [mangaUri].
  Future<void> deleteManga(String mangaUri);
}
