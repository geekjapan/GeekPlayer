import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/media_session.dart';

void main() {
  group('PagePosition', () {
    test('constructs with valid pageIndex and scrollFraction', () {
      final PagePosition p = PagePosition(pageIndex: 1, scrollFraction: 0.0);
      expect(p.pageIndex, 1);
      expect(p.scrollFraction, 0.0);

      final PagePosition q = PagePosition(pageIndex: 42, scrollFraction: 1.0);
      expect(q.pageIndex, 42);
      expect(q.scrollFraction, 1.0);
    });

    test('rejects pageIndex < 1', () {
      expect(
        () => PagePosition(pageIndex: 0, scrollFraction: 0.5),
        throwsArgumentError,
      );
      expect(
        () => PagePosition(pageIndex: -3, scrollFraction: 0.5),
        throwsArgumentError,
      );
    });

    test('rejects scrollFraction outside [0.0, 1.0]', () {
      expect(
        () => PagePosition(pageIndex: 1, scrollFraction: -0.01),
        throwsArgumentError,
      );
      expect(
        () => PagePosition(pageIndex: 1, scrollFraction: 1.5),
        throwsArgumentError,
      );
      expect(
        () => PagePosition(pageIndex: 1, scrollFraction: double.nan),
        throwsArgumentError,
      );
    });

    test('structural equality and hashCode', () {
      final PagePosition a = PagePosition(pageIndex: 3, scrollFraction: 0.5);
      final PagePosition b = PagePosition(pageIndex: 3, scrollFraction: 0.5);
      final PagePosition c = PagePosition(pageIndex: 3, scrollFraction: 0.25);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('copyWith replaces only specified fields', () {
      final PagePosition a = PagePosition(pageIndex: 2, scrollFraction: 0.5);
      final PagePosition b = a.copyWith(pageIndex: 4);
      expect(b.pageIndex, 4);
      expect(b.scrollFraction, 0.5);
    });
  });
}
