/// Supported local book formats.
enum BookFormat {
  pdf,
  epub;

  /// Return the [BookFormat] for a file [extension] (without leading dot,
  /// case-insensitive), or `null` when the extension is not supported.
  static BookFormat? fromExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'pdf' => BookFormat.pdf,
      'epub' => BookFormat.epub,
      _ => null,
    };
  }

  /// Stable string persisted to the drift `book_metadata.format` column.
  String get code => name; // 'pdf' | 'epub'
}
