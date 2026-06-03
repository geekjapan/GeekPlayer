import 'package:flutter/foundation.dart';

/// Format-neutral reading position within a book.
///
/// For PDF: [pageIndex] is the 1-based page number; [scrollFraction] is the
/// vertical scroll fraction within that page.
/// For EPUB: [pageIndex] is the 1-based chapter index in spine order;
/// [scrollFraction] is the vertical scroll fraction within the chapter body.
@immutable
class BookLocator {
  const BookLocator({required this.pageIndex, this.scrollFraction = 0.0});

  /// 1-based page (PDF) or chapter (EPUB) index.
  final int pageIndex;

  /// `[0.0, 1.0]` vertical scroll fraction. Defaults to `0.0`.
  final double scrollFraction;

  BookLocator copyWith({int? pageIndex, double? scrollFraction}) {
    return BookLocator(
      pageIndex: pageIndex ?? this.pageIndex,
      scrollFraction: scrollFraction ?? this.scrollFraction,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookLocator &&
          other.pageIndex == pageIndex &&
          other.scrollFraction == scrollFraction);

  @override
  int get hashCode => Object.hash(pageIndex, scrollFraction);

  @override
  String toString() =>
      'BookLocator(page: $pageIndex, scroll: ${scrollFraction.toStringAsFixed(3)})';
}
