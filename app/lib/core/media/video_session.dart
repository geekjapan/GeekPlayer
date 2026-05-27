part of 'media_session.dart';

/// `MediaSession` variant backed by [media_kit]'s `Player` (libmpv).
///
/// One `VideoSession` corresponds to a single `Player` instance and one
/// `VideoController` for the on-screen `Video` widget. The session is
/// designed to be owned by a Riverpod `AutoDispose` notifier — when the
/// player screen pops, `dispose()` runs and the libmpv handle is released.
///
/// **Testing**: use [VideoSession.fromStreams] to drive the stream
/// transformation logic without spinning up libmpv.
final class VideoSession extends MediaSession {
  /// Production constructor. Creates a fresh `media_kit` `Player` and
  /// initialises a `VideoController` ready to be attached to a `Video`
  /// widget. Call [open] to load a file.
  VideoSession()
      : _player = Player(),
        _ownsController = true {
    _videoController = VideoController(_player!);
    _attachStreams();
  }

  /// Test seam: inject an existing [Player] (typically a mock) and skip
  /// `VideoController` construction (it requires a real platform handle).
  @visibleForTesting
  VideoSession.forTest(Player player)
      : _player = player,
        _ownsController = false {
    _attachStreams();
  }

  /// Test seam: skip [Player] entirely and drive state transitions from
  /// caller-provided streams. Used by [VideoSession] unit tests so that
  /// the transform logic in `_attachStreams` can be verified without a
  /// platform handle. Commands ([play], [pause], …) become no-ops in
  /// this mode but still respect the disposed state.
  @visibleForTesting
  VideoSession.fromStreams({
    required Stream<Duration> position,
    required Stream<Duration> buffer,
    required Stream<Duration> duration,
    required Stream<bool> playing,
    required Stream<bool> completed,
  })  : _player = null,
        _ownsController = false {
    _subscriptions.add(position.listen((Duration p) {
      _lastPosition = p;
      _positionController.add(MediaPosition(
        position: p,
        bufferEnd: _lastBuffer,
      ));
    }));
    _subscriptions.add(buffer.listen((Duration b) {
      _lastBuffer = b;
      _positionController.add(MediaPosition(
        position: _lastPosition,
        bufferEnd: b,
      ));
    }));
    _subscriptions.add(duration.listen((Duration d) {
      _durationController.add(d == Duration.zero ? null : d);
    }));
    _subscriptions.add(playing.listen((bool p) {
      _lastPlaying = p;
      if (_lastCompleted) {
        _playStateController.add(const MediaPlayState.ended());
      } else if (p) {
        _playStateController.add(const MediaPlayState.playing());
      } else {
        _playStateController.add(const MediaPlayState.paused());
      }
    }));
    _subscriptions.add(completed.listen((bool c) {
      _lastCompleted = c;
      if (c) {
        _playStateController.add(const MediaPlayState.ended());
      } else if (_lastPlaying) {
        _playStateController.add(const MediaPlayState.playing());
      } else {
        _playStateController.add(const MediaPlayState.paused());
      }
    }));
  }

  final Player? _player;
  final bool _ownsController;
  VideoController? _videoController;

  final StreamController<MediaPosition> _positionController =
      StreamController<MediaPosition>.broadcast();
  final StreamController<MediaPlayState> _playStateController =
      StreamController<MediaPlayState>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  bool _disposed = false;
  MediaSpeed _speed = MediaSpeed.normal;
  Duration _lastPosition = Duration.zero;
  Duration _lastBuffer = Duration.zero;
  bool _lastPlaying = false;
  bool _lastCompleted = false;

  /// Underlying `media_kit` `Player`. Exposed for advanced control (e.g.
  /// subtitle track selection) not yet lifted into [MediaSession]. Returns
  /// `null` only inside the streams-only test constructor.
  Player? get player => _player;

  /// `VideoController` to be passed to `media_kit_video`'s `Video` widget.
  /// `null` only inside the test constructor before a controller is set.
  VideoController? get videoController => _videoController;

  @override
  Stream<MediaPosition> get positionStream => _positionController.stream;

  @override
  Stream<MediaPlayState> get playStateStream => _playStateController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  MediaSpeed get speed => _speed;

  /// Open a media [source] (file URI string) and start playback from
  /// [startAt] if provided.
  Future<void> open(String source, {Duration? startAt}) async {
    _ensureNotDisposed();
    _playStateController.add(const MediaPlayState.loading());
    final Player? p = _player;
    if (p == null) return;
    await p.open(Media(source));
    if (startAt != null && startAt > Duration.zero) {
      // media_kit may require a brief wait before seek lands; the seek
      // command itself queues so we don't need an explicit delay here.
      await p.seek(startAt);
    }
  }

  @override
  Future<void> play() async {
    _ensureNotDisposed();
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    await _player?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    _ensureNotDisposed();
    final Duration clamped =
        position < Duration.zero ? Duration.zero : position;
    await _player?.seek(clamped);
  }

  @override
  Future<void> setSpeed(MediaSpeed speed) async {
    _ensureNotDisposed();
    await _player?.setRate(speed.value);
    _speed = speed;
  }

  /// Cycle the embedded subtitle track between off and the first available
  /// embedded track. Returns `true` when a subtitle is now visible.
  Future<bool> toggleSubtitle() async {
    _ensureNotDisposed();
    final Player? p = _player;
    if (p == null) return false;
    final Tracks tracks = p.state.tracks;
    final SubtitleTrack current = p.state.track.subtitle;
    // Embedded subtitles only — skip `auto`, `no`, and any URI/data tracks.
    final List<SubtitleTrack> embedded = tracks.subtitle
        .where((SubtitleTrack t) =>
            t.id != 'auto' && t.id != 'no' && !t.uri && !t.data)
        .toList(growable: false);
    if (embedded.isEmpty) return false;
    if (current.id == 'no') {
      await p.setSubtitleTrack(embedded.first);
      return true;
    }
    await p.setSubtitleTrack(SubtitleTrack.no());
    return false;
  }

  /// Current playhead position. Useful when callers want to persist a
  /// [ResumePoint] synchronously without awaiting a stream tick.
  Duration get currentPosition => _lastPosition;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final StreamSubscription<Object?> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _positionController.close();
    await _playStateController.close();
    await _durationController.close();
    if (_ownsController) {
      // VideoController is disposed when the underlying Player is.
    }
    await _player?.dispose();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('VideoSession has been disposed');
    }
  }

  void _attachStreams() {
    final Player? p = _player;
    if (p == null) return;
    final PlayerStream s = p.stream;
    _subscriptions.add(s.position.listen((Duration p) {
      _lastPosition = p;
      _positionController.add(MediaPosition(
        position: p,
        bufferStart: Duration.zero,
        bufferEnd: _lastBuffer,
      ));
    }));
    _subscriptions.add(s.buffer.listen((Duration b) {
      _lastBuffer = b;
      _positionController.add(MediaPosition(
        position: _lastPosition,
        bufferStart: Duration.zero,
        bufferEnd: b,
      ));
    }));
    _subscriptions.add(s.duration.listen((Duration d) {
      _durationController.add(d == Duration.zero ? null : d);
    }));
    _subscriptions.add(s.playing.listen((bool playing) {
      _lastPlaying = playing;
      if (_lastCompleted) {
        _playStateController.add(const MediaPlayState.ended());
      } else if (playing) {
        _playStateController.add(const MediaPlayState.playing());
      } else {
        _playStateController.add(const MediaPlayState.paused());
      }
    }));
    _subscriptions.add(s.completed.listen((bool completed) {
      _lastCompleted = completed;
      if (completed) {
        _playStateController.add(const MediaPlayState.ended());
      } else if (_lastPlaying) {
        _playStateController.add(const MediaPlayState.playing());
      } else {
        _playStateController.add(const MediaPlayState.paused());
      }
    }));
  }
}

