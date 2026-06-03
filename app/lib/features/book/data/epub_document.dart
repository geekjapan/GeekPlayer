import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/book_document.dart';
import '../domain/book_locator.dart';
import '../domain/book_metadata.dart';

/// A single EPUB chapter: spine index (1-based), id, and resolved HTML body.
class EpubChapter {
  const EpubChapter({
    required this.index,
    required this.id,
    required this.title,
    required this.htmlContent,
  });

  final int index;
  final String id;
  final String title;
  final String htmlContent;
}

/// [BookDocument] adapter for EPUB files.
///
/// Parses the EPUB ZIP container using `archive`, extracts OPF spine and
/// manifest, and exposes chapter HTML for rendering. No third-party EPUB
/// library — avoids version conflicts with `image` / `archive` transitive deps.
class EpubBookDocument implements BookDocument {
  EpubBookDocument({required this.metadata, required this.chapters});

  @override
  final BookMetadata metadata;

  final List<EpubChapter> chapters;

  BookLocator _locator = const BookLocator(pageIndex: 1);

  @override
  int get pageCount => chapters.length;

  @override
  BookLocator get currentLocator => _locator;

  @override
  Future<void> goToPage(int pageIndex) async {
    final int clamped = pageIndex.clamp(1, pageCount.clamp(1, pageCount));
    _locator = BookLocator(pageIndex: clamped);
  }

  @override
  Future<void> updateScrollFraction(double fraction) async {
    _locator = _locator.copyWith(scrollFraction: fraction.clamp(0.0, 1.0));
  }

  @override
  Future<void> dispose() async {} // pure-Dart; nothing to release.

  /// Open an EPUB from [path] and return an [EpubBookDocument].
  static Future<EpubBookDocument> open(
    String path,
    BookMetadata metadata,
  ) async {
    final Uint8List bytes = File(path).readAsBytesSync();
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    // Find container.xml to locate the OPF.
    final ArchiveFile? containerFile = archive.findFile(
      'META-INF/container.xml',
    );
    if (containerFile == null) {
      throw const FormatException(
        'Invalid EPUB: META-INF/container.xml not found',
      );
    }

    final XmlDocument container = XmlDocument.parse(
      String.fromCharCodes(containerFile.content as List<int>),
    );
    final String? opfPath = container
        .findAllElements('rootfile')
        .firstOrNull
        ?.getAttribute('full-path');
    if (opfPath == null) {
      throw const FormatException(
        'Invalid EPUB: OPF path not found in container.xml',
      );
    }

    final ArchiveFile? opfFile = archive.findFile(opfPath);
    if (opfFile == null) {
      throw FormatException('Invalid EPUB: OPF file not found at $opfPath');
    }

    final XmlDocument opf = XmlDocument.parse(
      String.fromCharCodes(opfFile.content as List<int>),
    );

    // Base directory for resolving relative hrefs.
    final String opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    // Build manifest map: id -> href.
    final Map<String, String> manifest = <String, String>{};
    for (final XmlElement item in opf.findAllElements('item')) {
      final String? id = item.getAttribute('id');
      final String? href = item.getAttribute('href');
      if (id != null && href != null) {
        manifest[id] = href;
      }
    }

    // Extract spine itemrefs in order.
    final List<String> spineIds = opf
        .findAllElements('itemref')
        .map((XmlElement e) => e.getAttribute('idref') ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();

    // Build toc titles from NCX (best effort).
    final Map<String, String> tocTitles = _parseTocTitles(
      archive,
      opfDir,
      manifest,
    );

    final List<EpubChapter> chapters = <EpubChapter>[];
    for (int i = 0; i < spineIds.length; i++) {
      final String id = spineIds[i];
      final String? href = manifest[id];
      if (href == null) continue;
      final String fullPath = '$opfDir$href';
      final ArchiveFile? chapterFile = archive.findFile(fullPath);
      if (chapterFile == null) continue;
      final String html = String.fromCharCodes(
        chapterFile.content as List<int>,
      );
      final String title = tocTitles[href] ?? 'Chapter ${i + 1}';
      chapters.add(
        EpubChapter(index: i + 1, id: id, title: title, htmlContent: html),
      );
    }

    if (chapters.isEmpty) {
      throw const FormatException('EPUB has no readable chapters');
    }

    return EpubBookDocument(metadata: metadata, chapters: chapters);
  }

  static Map<String, String> _parseTocTitles(
    Archive archive,
    String opfDir,
    Map<String, String> manifest,
  ) {
    final Map<String, String> titles = <String, String>{};
    // Find NCX item.
    final String? ncxHref = manifest.entries
        .where(
          (MapEntry<String, String> e) =>
              e.value.endsWith('.ncx') ||
              manifest.keys.contains('ncx') && e.key == 'ncx',
        )
        .map((MapEntry<String, String> e) => e.value)
        .firstOrNull;
    if (ncxHref == null) return titles;
    final ArchiveFile? ncxFile = archive.findFile('$opfDir$ncxHref');
    if (ncxFile == null) return titles;
    try {
      final XmlDocument ncx = XmlDocument.parse(
        String.fromCharCodes(ncxFile.content as List<int>),
      );
      for (final XmlElement navPoint in ncx.findAllElements('navPoint')) {
        final String? label = navPoint
            .findElements('navLabel')
            .firstOrNull
            ?.findElements('text')
            .firstOrNull
            ?.innerText;
        final String? src = navPoint
            .findElements('content')
            .firstOrNull
            ?.getAttribute('src');
        if (label != null && src != null) {
          // src may contain fragment (#...); strip it.
          final String href = src.contains('#') ? src.split('#').first : src;
          titles[href] = label;
        }
      }
    } catch (_) {
      // NCX parse failure is non-fatal; chapters will use fallback titles.
    }
    return titles;
  }
}
