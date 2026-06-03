import 'package:flutter/foundation.dart';

import 'book_locator.dart';

/// A named position inside a book.
@immutable
class BookBookmark {
  const BookBookmark({
    required this.id,
    required this.bookUri,
    required this.label,
    required this.locator,
    required this.createdAt,
  });

  final int id;
  final String bookUri;
  final String label;
  final BookLocator locator;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BookBookmark && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BookBookmark($id, $label, $locator)';
}
