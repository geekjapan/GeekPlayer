import 'dart:async';

import '../../../core/media/media_session.dart';
import '../../../core/media/models.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/storage/database.dart';

/// `PageSession` implementation backed by the drift `novel_bookmarks`
/// table.
///
/// Owns no native resources beyond a handful of broadcast
/// [StreamController]s. Constructed by the (future) reader screen when
/// it opens a Library Work; disposed when the screen pops. On dispose
/// the current [PagePosition] is upserted into `novel_bookmarks` so the
/// next open resumes at the same scroll fraction (design.md D9 /
/// spec `media-session` "PageSession persists position to
/// novel_bookmarks on dispose").
final class NovelPageSession extends PageSession {
  NovelPageSession({
    required this.workId,
    required NovelBookmarksDao bookmarksDao,
    required this.totalPages,
    PagePosition? initial,
  })  : _bookmarksDao = bookmarksDao, // ignore: prefer_initializing_formals
        _current = initial ??
            PagePosition(pageIndex: 1, scrollFraction: 0.0) {
    // Emit the initial position immediately so subscribers see at
    // least one event within 500ms (spec scenario "PageSession can be
    // observed for reading progress").
    _pagePositionController.add(_current);
    _playStateController.add(const MediaPlayState.paused());
    _positionController.add(MediaPosition.zero);
    _durationController.add(null);
  }

  final WorkId workId;
  final NovelBookmarksDao _bookmarksDao;

  @override
  final int totalPages;
  PagePosition _current;
  bool _disposed = false;
  MediaSpeed _speed = MediaSpeed.normal;

  final StreamController<PagePosition> _pagePositionController =
      StreamController<PagePosition>.broadcast();
  final StreamController<MediaPosition> _positionController =
      StreamController<MediaPosition>.broadcast();
  final StreamController<MediaPlayState> _playStateController =
      StreamController<MediaPlayState>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();

  /// Visible for tests: the most recently emitted position.
  PagePosition get currentForTest => _current;

  @override
  Stream<PagePosition> get pagePositionStream async* {
    // Spec `media-session` "PageSession can be observed for reading
    // progress" — first event within 500 ms of subscription. Replay
    // the current snapshot synchronously, then forward all subsequent
    // emissions from the broadcast controller.
    yield _current;
    yield* _pagePositionController.stream;
  }

  @override
  Stream<MediaPosition> get positionStream => _positionController.stream;

  @override
  Stream<MediaPlayState> get playStateStream =>
      _playStateController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  MediaSpeed get speed => _speed;

  @override
  Future<void> goToPage(int index) async {
    _ensureNotDisposed();
    final int clamped = totalPages > 0
        ? index.clamp(1, totalPages)
        : (index < 1 ? 1 : index);
    _current = PagePosition(pageIndex: clamped, scrollFraction: 0.0);
    _pagePositionController.add(_current);
  }

  @override
  Future<void> updateScrollFraction(double fraction) async {
    _ensureNotDisposed();
    if (fraction.isNaN || fraction < 0.0 || fraction > 1.0) {
      throw ArgumentError.value(
        fraction,
        'fraction',
        'scrollFraction must be in [0.0, 1.0]',
      );
    }
    _current = _current.copyWith(scrollFraction: fraction);
    _pagePositionController.add(_current);
  }

  @override
  Future<void> play() async {
    _ensureNotDisposed();
    // v0.1: auto-scroll is stubbed. Reflect "playing" state for
    // observers (future audiobook narration hook).
    _playStateController.add(const MediaPlayState.playing());
  }

  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    _playStateController.add(const MediaPlayState.paused());
  }

  @override
  Future<void> seek(Duration position) async {
    throw UnsupportedError(
      'PageSession does not support seek(Duration); use goToPage(int) '
      'instead.',
    );
  }

  @override
  Future<void> setSpeed(MediaSpeed speed) async {
    _ensureNotDisposed();
    _speed = speed;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Best-effort persistence: errors are swallowed so that a flaky DB
    // cannot leak through the reader-screen dispose path. drift
    // surfaces the same row via `getBookmark` next open if the write
    // succeeded.
    try {
      await _bookmarksDao.upsertBookmark(
        site: workId.site.code,
        externalId: workId.externalId,
        episodeIndex: _current.pageIndex,
        scrollFraction: _current.scrollFraction,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      // Intentionally swallowed.
    }

    await _pagePositionController.close();
    await _positionController.close();
    await _playStateController.close();
    await _durationController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('NovelPageSession has been disposed');
    }
  }
}
