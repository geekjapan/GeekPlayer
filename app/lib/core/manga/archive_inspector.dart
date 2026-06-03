import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../errors/app_error.dart';

/// Limits applied before any decoding to protect against resource exhaustion
/// (design.md Risk §1 / spec manga-archive-safety).
const int kMaxEntryCount = 2000;
const int kMaxTotalUncompressedBytes = 500 * 1024 * 1024; // 500 MB
const int kMaxSingleEntryBytes = 100 * 1024 * 1024; // 100 MB

/// Image extensions treated as candidate manga pages (lower-cased).
const Set<String> kSupportedImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
};

/// A single validated image entry inside an archive.
class MangaArchiveEntry {
  const MangaArchiveEntry({required this.name, required this.uncompressedSize});

  /// Entry name relative to the archive root (safe: no traversal components).
  final String name;

  /// Uncompressed byte count as declared in the ZIP local-file header.
  final int uncompressedSize;
}

/// Result of [ArchiveInspector.inspect].
class MangaArchiveInfo {
  const MangaArchiveInfo({required this.pages, required this.archivePath});

  /// Sorted image pages. All entries have passed safety checks.
  final List<MangaArchiveEntry> pages;

  /// Absolute path to the archive file.
  final String archivePath;
}

/// Safe, in-memory ZIP/CBZ inspector.
///
/// Does NOT extract entries to the filesystem. All bytes are read into memory
/// only when [readPageBytes] is called. The inspector validates:
///
/// - Archive extension must be `.zip` or `.cbz` (D1).
/// - Entry count ≤ [kMaxEntryCount].
/// - Total uncompressed bytes ≤ [kMaxTotalUncompressedBytes].
/// - Single-entry uncompressed bytes ≤ [kMaxSingleEntryBytes].
/// - Path traversal (`..`, absolute paths) → skipped.
/// - Hidden metadata (`__MACOSX/`, dotfiles) → skipped.
/// - Directory entries → skipped.
/// - Non-image extensions → skipped.
///
/// Throws [AppError] subclasses; never lets raw archive exceptions escape.
class ArchiveInspector {
  const ArchiveInspector();

  /// Inspect [archivePath] and return the list of valid image pages.
  ///
  /// Throws:
  /// - [FileNotFoundError] if the file does not exist.
  /// - [UnsupportedFormatError] if the extension is not cbz/zip.
  /// - [UnsupportedFormatError] if the archive has no valid image pages.
  /// - [UnknownError] wrapping corrupt / unreadable archives.
  Future<MangaArchiveInfo> inspect(String archivePath) async {
    final File file = File(archivePath);
    if (!file.existsSync()) {
      throw FileNotFoundError(
        message: 'Archive not found: $archivePath',
        uri: Uri.file(archivePath),
      );
    }

    final String ext = p
        .extension(archivePath)
        .replaceFirst('.', '')
        .toLowerCase();
    if (ext != 'cbz' && ext != 'zip') {
      throw UnsupportedFormatError(
        message: 'Unsupported archive format: .$ext',
        extension: ext,
      );
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }

    // Entry count check (before iterating to avoid iterating a 10M-entry bomb).
    if (archive.length > kMaxEntryCount) {
      throw UnsupportedFormatError(
        message:
            'Archive has ${archive.length} entries, exceeds limit of $kMaxEntryCount',
        extension: ext,
      );
    }

    int totalBytes = 0;
    final List<MangaArchiveEntry> candidates = <MangaArchiveEntry>[];

    for (final ArchiveFile entry in archive) {
      // Skip directories.
      if (entry.isDirectory) continue;

      final String name = entry.name;

      // Skip path-traversal entries.
      if (_hasPathTraversal(name)) continue;

      // Skip hidden metadata directories (macOS resource forks, etc.).
      if (_isHiddenOrMetadata(name)) continue;

      // Skip non-image files.
      final String entryExt = p
          .extension(name)
          .replaceFirst('.', '')
          .toLowerCase();
      if (!kSupportedImageExtensions.contains(entryExt)) continue;

      // Single-entry size check.
      final int uncompressed = entry.size;
      if (uncompressed > kMaxSingleEntryBytes) continue; // skip oversized page

      // Total bytes accumulation.
      totalBytes += uncompressed;
      if (totalBytes > kMaxTotalUncompressedBytes) {
        throw UnsupportedFormatError(
          message:
              'Archive total uncompressed size exceeds limit of $kMaxTotalUncompressedBytes bytes',
          extension: ext,
        );
      }

      candidates.add(
        MangaArchiveEntry(name: name, uncompressedSize: uncompressed),
      );
    }

    if (candidates.isEmpty) {
      throw UnsupportedFormatError(
        message: 'Archive contains no supported image pages',
        extension: ext,
      );
    }

    // Natural filename ordering (D5).
    candidates.sort(
      (MangaArchiveEntry a, MangaArchiveEntry b) =>
          _naturalCompare(a.name, b.name),
    );

    return MangaArchiveInfo(
      pages: List<MangaArchiveEntry>.unmodifiable(candidates),
      archivePath: archivePath,
    );
  }

  /// Read and return the raw bytes for [entry] inside [archivePath].
  ///
  /// Throws [UnknownError] on I/O or decode error.
  Future<Uint8List> readPageBytes(
    String archivePath,
    MangaArchiveEntry entry,
  ) async {
    final Uint8List bytes;
    try {
      bytes = await File(archivePath).readAsBytes();
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e, st) {
      throw UnknownError(e, stackTrace: st);
    }

    for (final ArchiveFile af in archive) {
      if (af.name == entry.name) {
        try {
          // archive ^4.0.9: content is typed as dynamic / Object,
          // pattern-match to avoid unnecessary cast warning.
          final dynamic raw = af.content;
          if (raw is Uint8List) return raw;
          return Uint8List.fromList((raw as List<int>));
        } catch (e, st) {
          throw UnknownError(e, stackTrace: st);
        }
      }
    }

    throw UnknownError('Entry not found in archive: ${entry.name}');
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static bool _hasPathTraversal(String name) {
    // Absolute paths (POSIX or Windows) or `..` components are unsafe.
    if (p.isAbsolute(name)) return true;
    final List<String> parts = name.replaceAll('\\', '/').split('/');
    return parts.contains('..') || parts.contains('.');
  }

  static bool _isHiddenOrMetadata(String name) {
    final String normalized = name.replaceAll('\\', '/');
    final List<String> parts = normalized.split('/');
    for (final String part in parts) {
      // Skip __MACOSX resource-fork directories.
      if (part == '__MACOSX') return true;
      // Skip dotfiles and hidden directories (.DS_Store, .Thumbs.db, etc.).
      if (part.startsWith('.') && part.length > 1) return true;
    }
    return false;
  }

  /// Natural sort: splits strings into alternating numeric and non-numeric
  /// segments and compares them so `2.jpg` sorts before `10.jpg`.
  static int _naturalCompare(String a, String b) {
    final List<String> aParts = _splitNatural(a);
    final List<String> bParts = _splitNatural(b);
    final int len = aParts.length < bParts.length
        ? aParts.length
        : bParts.length;
    for (int i = 0; i < len; i++) {
      final String ap = aParts[i];
      final String bp = bParts[i];
      final int? an = int.tryParse(ap);
      final int? bn = int.tryParse(bp);
      final int cmp;
      if (an != null && bn != null) {
        cmp = an.compareTo(bn);
      } else {
        cmp = ap.compareTo(bp);
      }
      if (cmp != 0) return cmp;
    }
    return aParts.length.compareTo(bParts.length);
  }

  static List<String> _splitNatural(String s) {
    final List<String> parts = <String>[];
    final StringBuffer buf = StringBuffer();
    bool inDigit = false;
    for (final int code in s.codeUnits) {
      final bool isDigit = code >= 48 && code <= 57; // '0'..'9'
      if (buf.isNotEmpty && isDigit != inDigit) {
        parts.add(buf.toString());
        buf.clear();
      }
      buf.writeCharCode(code);
      inDigit = isDigit;
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }
}
