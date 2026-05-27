part of 'media_session.dart';

/// Immutable value object for a reader's position within an episode.
///
/// Lives in the same library as [MediaSession] (via `part of`) so that
/// [PageSession]'s API surface can return it without cross-library
/// imports. See CONVENTIONS.md §10 and GRILL-REPORT Q-CROSS-011 for the
/// rationale behind the part-of layout.
///
/// `scrollFraction` is stored as a `[0.0, 1.0]` ratio (NOT a pixel
/// offset) so the saved point survives font / layout / window-size
/// changes (design.md D9).
@immutable
class PagePosition {
  PagePosition({required this.pageIndex, required this.scrollFraction}) {
    if (pageIndex < 1) {
      throw ArgumentError.value(
        pageIndex,
        'pageIndex',
        'pageIndex must be >= 1',
      );
    }
    if (scrollFraction.isNaN ||
        scrollFraction < 0.0 ||
        scrollFraction > 1.0) {
      throw ArgumentError.value(
        scrollFraction,
        'scrollFraction',
        'scrollFraction must be in [0.0, 1.0]',
      );
    }
  }

  /// 1-based page (episode) index.
  final int pageIndex;

  /// `[0.0, 1.0]` ratio of the current scroll offset relative to the
  /// page's scrollable extent.
  final double scrollFraction;

  PagePosition copyWith({int? pageIndex, double? scrollFraction}) {
    return PagePosition(
      pageIndex: pageIndex ?? this.pageIndex,
      scrollFraction: scrollFraction ?? this.scrollFraction,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PagePosition &&
        other.pageIndex == pageIndex &&
        other.scrollFraction == scrollFraction;
  }

  @override
  int get hashCode => Object.hash(pageIndex, scrollFraction);

  @override
  String toString() =>
      'PagePosition(page: $pageIndex, scroll: ${scrollFraction.toStringAsFixed(3)})';
}
