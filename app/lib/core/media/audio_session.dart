part of 'media_session.dart';

/// `MediaSession` variant backed by [just_audio]'s `AudioPlayer` and
/// integrated with `audio_service` via [AudioHandler].
///
/// One [AudioSession] is owned by the audio player controller and holds
/// the lifetime of a single track / queue position. The OS-facing
/// foreground notification, headphone buttons, and lock-screen surface
/// are driven by the shared [AudioHandler] (see `audio_handler.dart`),
/// which forwards play / pause / seek / skip events back into the
/// [AudioPlayer] held here.
///
/// **Testing**: use [AudioSession.forTest] to inject a fake [AudioPlayer]
/// (typically via `mocktail`) so the stream transformation logic can be
/// exercised without spinning up a native engine.
final class AudioSession extends MediaSession {
  /// Production constructor — wraps the [AudioPlayer] owned by the shared
  /// [AudioHandler] (see `audio_handler.dart`). One [AudioSession] is
  /// created per "current track / queue" instance, but all sessions in
  /// a process drive the same player so the OS notification surface is
  /// always coherent with the in-app UI.
  AudioSession.usingPlayer(AudioPlayer player, {AudioHandler? handler})
    : _player = player,
      // ignore: prefer_initializing_formals — keep the named param.
      _handler = handler {
    _attachStreams(player);
  }

  /// Test seam: inject a fake or mock [AudioPlayer]. The handler binding
  /// is optional and defaults to `null`, in which case OS integration is
  /// a no-op (which is what unit tests want).
  @visibleForTesting
  AudioSession.forTest(AudioPlayer player, {AudioHandler? handler})
    : _player = player,
      // ignore: prefer_initializing_formals — keep the named param for clarity
      _handler = handler {
    _attachStreams(player);
  }

  /// Test seam: skip [AudioPlayer] entirely and drive state transitions
  /// from caller-provided streams. Used by [AudioSession] unit tests so
  /// the transformation logic in `_attachStreams` can be verified without
  /// a platform handle. Commands ([play], [pause], …) become no-ops in
  /// this mode but still respect the disposed flag.
  @visibleForTesting
  AudioSession.fromStreams({
    required Stream<Duration> position,
    required Stream<Duration> bufferedPosition,
    required Stream<Duration?> duration,
    required Stream<PlayerState> playerState,
  }) : _player = null {
    _subscriptions.add(
      position.listen((Duration p) {
        _lastPosition = p;
        _positionController.add(
          MediaPosition(position: p, bufferEnd: _lastBuffer),
        );
      }),
    );
    _subscriptions.add(
      bufferedPosition.listen((Duration b) {
        _lastBuffer = b;
        _positionController.add(
          MediaPosition(position: _lastPosition, bufferEnd: b),
        );
      }),
    );
    _subscriptions.add(
      duration.listen((Duration? d) {
        _durationController.add(d);
      }),
    );
    _subscriptions.add(
      playerState.listen((PlayerState ps) {
        _playStateController.add(_mapPlayerState(ps));
      }),
    );
  }

  final AudioPlayer? _player;
  AudioHandler? _handler;

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

  /// Underlying [AudioPlayer]. Exposed for advanced wiring (e.g. the
  /// [AudioHandler] needs to subscribe to its event streams to publish
  /// `MediaItem` updates to the OS). `null` only inside the streams-only
  /// test seam.
  AudioPlayer? get player => _player;

  /// Currently bound [AudioHandler] (or `null` when no OS integration is
  /// active — typically in unit tests).
  AudioHandler? get handler => _handler;

  /// Bind an [AudioHandler] after construction. Called by the audio
  /// controller once `AudioService.init` has resolved. Idempotent: a
  /// later call replaces the binding.
  void bindHandler(AudioHandler handler) {
    _handler = handler;
  }

  /// Open a media [source] (file URI string) and start from [startAt] if
  /// provided. Playback is **not** auto-started; the caller calls [play]
  /// once the desired position is reached.
  Future<void> open(String source, {Duration? startAt}) async {
    _ensureNotDisposed();
    _playStateController.add(const MediaPlayState.loading());
    final AudioPlayer? p = _player;
    if (p == null) return;
    await p.setAudioSource(
      AudioSource.uri(Uri.parse(source)),
      initialPosition: startAt,
    );
  }

  @override
  Stream<MediaPosition> get positionStream => _positionController.stream;

  @override
  Stream<MediaPlayState> get playStateStream => _playStateController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  MediaSpeed get speed => _speed;

  @override
  Future<void> play() async {
    _ensureNotDisposed();
    final AudioPlayer? p = _player;
    if (p == null) return;
    // Fire-and-forget on play — just_audio's `play()` only completes when
    // playback ends, which would block the caller indefinitely.
    unawaited(p.play());
  }

  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    await _player?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    _ensureNotDisposed();
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : position;
    await _player?.seek(clamped);
  }

  @override
  Future<void> setSpeed(MediaSpeed speed) async {
    _ensureNotDisposed();
    await _player?.setSpeed(speed.value);
    _speed = speed;
  }

  /// Current playhead position. Useful when callers want to persist a
  /// ResumePoint synchronously without awaiting a stream tick.
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
    // We do NOT call `_player.dispose()` here: the AudioPlayer is owned
    // by the shared GeekPlayerAudioHandler (singleton). The session
    // only owns its own stream controllers + subscriptions, which we
    // released above. See design.md "Risks / Trade-offs".
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('AudioSession has been disposed');
    }
  }

  void _attachStreams(AudioPlayer player) {
    _subscriptions.add(
      player.positionStream.listen((Duration p) {
        _lastPosition = p;
        _positionController.add(
          MediaPosition(position: p, bufferEnd: _lastBuffer),
        );
      }),
    );
    _subscriptions.add(
      player.bufferedPositionStream.listen((Duration b) {
        _lastBuffer = b;
        _positionController.add(
          MediaPosition(position: _lastPosition, bufferEnd: b),
        );
      }),
    );
    _subscriptions.add(
      player.durationStream.listen((Duration? d) {
        _durationController.add(d);
      }),
    );
    _subscriptions.add(
      player.playerStateStream.listen((PlayerState ps) {
        _playStateController.add(_mapPlayerState(ps));
      }),
    );
  }

  /// Translate just_audio's [PlayerState] (a `(playing, processingState)`
  /// tuple) into the project's high-level [MediaPlayState].
  static MediaPlayState _mapPlayerState(PlayerState ps) {
    switch (ps.processingState) {
      case ProcessingState.idle:
        return const MediaPlayState.idle();
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return const MediaPlayState.loading();
      case ProcessingState.ready:
        return ps.playing
            ? const MediaPlayState.playing()
            : const MediaPlayState.paused();
      case ProcessingState.completed:
        return const MediaPlayState.ended();
    }
  }
}
