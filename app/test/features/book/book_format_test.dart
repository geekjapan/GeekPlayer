import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/book/domain/book_format.dart';

/// Task 6.1 — format detection and unsupported-format rejection.
void main() {
  group('BookFormat.fromExtension', () {
    test('recognises pdf (lowercase)', () {
      expect(BookFormat.fromExtension('pdf'), BookFormat.pdf);
    });

    test('recognises epub (lowercase)', () {
      expect(BookFormat.fromExtension('epub'), BookFormat.epub);
    });

    test('is case-insensitive', () {
      expect(BookFormat.fromExtension('PDF'), BookFormat.pdf);
      expect(BookFormat.fromExtension('EPUB'), BookFormat.epub);
    });

    test('returns null for unsupported extensions', () {
      expect(BookFormat.fromExtension('cbz'), isNull);
      expect(BookFormat.fromExtension('mobi'), isNull);
      expect(BookFormat.fromExtension('txt'), isNull);
      expect(BookFormat.fromExtension(''), isNull);
    });
  });

  group('BookFormat.code', () {
    test('returns stable lowercase string', () {
      expect(BookFormat.pdf.code, 'pdf');
      expect(BookFormat.epub.code, 'epub');
    });
  });
}
