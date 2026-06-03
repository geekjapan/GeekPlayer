import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/book/domain/book_locator.dart';

/// Task 6.4 — reader resume tests (locator value equality).
void main() {
  group('BookLocator', () {
    test('default scrollFraction is 0.0', () {
      const BookLocator loc = BookLocator(pageIndex: 3);
      expect(loc.scrollFraction, 0.0);
    });

    test('copyWith updates only the requested field', () {
      const BookLocator loc = BookLocator(pageIndex: 5, scrollFraction: 0.5);
      expect(loc.copyWith(pageIndex: 7).pageIndex, 7);
      expect(loc.copyWith(pageIndex: 7).scrollFraction, 0.5);
      expect(loc.copyWith(scrollFraction: 0.9).pageIndex, 5);
    });

    test('equality is structural', () {
      const BookLocator a = BookLocator(pageIndex: 1, scrollFraction: 0.25);
      const BookLocator b = BookLocator(pageIndex: 1, scrollFraction: 0.25);
      const BookLocator c = BookLocator(pageIndex: 2, scrollFraction: 0.25);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode matches equality contract', () {
      const BookLocator a = BookLocator(pageIndex: 2, scrollFraction: 0.1);
      const BookLocator b = BookLocator(pageIndex: 2, scrollFraction: 0.1);
      expect(a.hashCode, b.hashCode);
    });
  });
}
