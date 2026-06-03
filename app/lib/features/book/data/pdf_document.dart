import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../domain/book_document.dart';
import '../domain/book_locator.dart';
import '../domain/book_metadata.dart';

/// [BookDocument] adapter for PDF files, backed by `pdfrx`.
///
/// Lazy page rendering is handled entirely by [PdfViewer] in the presentation
/// layer; this adapter owns metadata and locator state only.
class PdfBookDocument implements BookDocument {
  PdfBookDocument({required this.metadata, required this.pdfDocument});

  @override
  final BookMetadata metadata;

  final PdfDocument pdfDocument;

  BookLocator _locator = const BookLocator(pageIndex: 1);

  @override
  int get pageCount => pdfDocument.pages.length;

  @override
  BookLocator get currentLocator => _locator;

  @override
  Future<void> goToPage(int pageIndex) async {
    final int clamped = pageIndex.clamp(1, pageCount.clamp(1, pageCount));
    _locator = BookLocator(pageIndex: clamped);
  }

  @override
  Future<void> updateScrollFraction(double fraction) async {
    assert(fraction >= 0.0 && fraction <= 1.0);
    _locator = _locator.copyWith(scrollFraction: fraction.clamp(0.0, 1.0));
  }

  @override
  Future<void> dispose() => pdfDocument.dispose();

  /// Open a PDF from [path] and return a [PdfBookDocument].
  static Future<PdfBookDocument> open(
    String path,
    BookMetadata metadata,
  ) async {
    final File f = File(path);
    if (!f.existsSync()) {
      throw StateError('File not found: $path');
    }
    final PdfDocument pdf = await PdfDocument.openFile(path);
    return PdfBookDocument(metadata: metadata, pdfDocument: pdf);
  }
}
