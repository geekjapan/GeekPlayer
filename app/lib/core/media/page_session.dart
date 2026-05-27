part of 'media_session.dart';

/// `MediaSession` variant for page-oriented reading (online novels in
/// v0.1; book / manga in v0.2). See design.md D9 and ADR-0001 §reader.
///
/// Lives in the same library as [VideoSession] / [AudioSession] (via
/// `part of`) to satisfy Dart 3's "sealed class subtypes must share a
/// library" constraint — CONVENTIONS.md §10. Concrete implementations
/// (e.g. `NovelPageSession` for online novels) live under
/// `app/lib/features/novel/data/` and extend this class.
///
/// Semantic re-interpretation of inherited [MediaSession] methods:
///
/// - [play] / [pause] — start / stop optional auto-scroll. v0.1 readers
///   expose no UI for this yet; the methods are present so future
///   audiobook narration can hook into the same surface.
/// - [seek] — **throws [UnsupportedError]**. Page navigation has no
///   time-based representation. Callers MUST use [goToPage] instead.
/// - [setSpeed] — adjusts auto-scroll speed (no-op when auto-scroll is
///   off).
///
/// Lifecycle: on [dispose], implementations MUST upsert the current
/// [PagePosition] into the `novel_bookmarks` table so the next open
/// resumes at the same scroll fraction (design.md D9 / Q-D2).
abstract class PageSession extends MediaSession {
  /// Stream of position updates. First event SHOULD be emitted within
  /// 500ms of subscription.
  Stream<PagePosition> get pagePositionStream;

  /// Total page (episode) count once known. Implementations MAY return
  /// `0` before the source has been loaded.
  int get totalPages;

  /// Jump to [index] (1-based). Implementations clamp to
  /// `[1, totalPages]` and emit a [PagePosition] with
  /// `scrollFraction == 0.0`.
  Future<void> goToPage(int index);

  /// Update the scroll fraction within the current page. Must be in
  /// `[0.0, 1.0]`; out-of-range values throw [ArgumentError].
  Future<void> updateScrollFraction(double fraction);
}
