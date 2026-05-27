/// Writing direction for the novel reader.
///
/// Persisted as the literal lower-case name (`'vertical'` / `'horizontal'`).
/// `EnumCodec<NovelWritingMode>` (see `settings_codec.dart`) does the
/// string round-trip.
enum NovelWritingMode {
  vertical,
  horizontal;

  /// Lookup by persisted name. Returns `null` for unknown strings so
  /// callers can fall back to the default.
  static NovelWritingMode? fromName(String name) {
    for (final NovelWritingMode m in NovelWritingMode.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}
