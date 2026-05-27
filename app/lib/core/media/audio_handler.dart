import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// `audio_service` [BaseAudioHandler] backed by a single shared
/// [AudioPlayer] from `just_audio`.
///
/// One instance is created at app startup via `AudioService.init` (see
/// `main.dart`) and lives for the lifetime of the process. Its
/// [AudioPlayer] is the same one held by the active [AudioSession];
/// commands coming from the OS (lock screen, headphone buttons, etc.)
/// land here and are forwarded to that player, so the on-screen UI and
/// the OS-side controls always operate on the same playback engine.
///
/// The handler does **not** decide what to play next when a track ends;
/// queue advancement (shuffle / repeat / skip on completion) is driven
/// by the audio controller notifier in `features/audio/presentation/`,
/// which subscribes to `player.processingStateStream`. Keeping that
/// logic out of the handler lets us unit-test the queue rules in pure
/// Dart and keeps the handler thin.
class GeekPlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  GeekPlayerAudioHandler() {
    _wire();
  }

  final AudioPlayer _player = AudioPlayer();

  /// The single [AudioPlayer] every [AudioSession] should drive. Exposed
  /// so the controller notifier can construct an [AudioSession] that
  /// shares the same player (and therefore the same OS notification).
  AudioPlayer get player => _player;

  /// Update the OS-facing now-playing card. Call this when the current
  /// track changes (e.g. user picks a new file, queue advances).
  Future<void> updateNowPlaying(MediaItem item) async {
    mediaItem.add(item);
  }

  /// Clear the now-playing card (e.g. when the queue is empty / disposed).
  Future<void> clearNowPlaying() async {
    mediaItem.add(null);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Default skipToNext / skipToPrevious are no-ops — the controller
  /// notifier overrides this behaviour by listening to OS events via the
  /// `playbackState` we publish. We still surface the *capability* in
  /// [PlaybackState.controls] so the OS shows the buttons; pressing them
  /// invokes these methods, which we expose as hooks the controller can
  /// override at runtime.
  @override
  Future<void> skipToNext() async {
    final VoidCallback? hook = _onSkipNext;
    if (hook != null) hook();
  }

  @override
  Future<void> skipToPrevious() async {
    final VoidCallback? hook = _onSkipPrevious;
    if (hook != null) hook();
  }

  VoidCallback? _onSkipNext;
  VoidCallback? _onSkipPrevious;

  /// Register callbacks for the OS skip-next / skip-previous buttons.
  /// Pass `null` to clear. Called by the controller notifier when the
  /// queue is created and disposed.
  void setSkipHandlers({VoidCallback? onNext, VoidCallback? onPrevious}) {
    _onSkipNext = onNext;
    _onSkipPrevious = onPrevious;
  }

  /// Build a [PlaybackState] from the current [AudioPlayer] event.
  ///
  /// Combines the player's `playing` flag, `processingState`, and
  /// position so the OS sees a single coherent state.
  void _wire() {
    // Republish player events as PlaybackState updates.
    _player.playbackEventStream.listen(_broadcastState);
    // Forwarding position discontinuities (seek / track change) ensures
    // the OS shows the correct position immediately.
    _player.positionDiscontinuityStream.listen((_) {
      _broadcastState(_player.playbackEvent);
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final bool playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState:
            const <ProcessingState, AudioProcessingState>{
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[event.processingState] ??
            AudioProcessingState.idle,
        playing: playing,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  /// Release the underlying player. Called only on app shutdown — the
  /// handler is a process-wide singleton.
  Future<void> shutdown() async {
    await _player.dispose();
  }
}

/// `VoidCallback` is in dart:ui via package:flutter but we want this
/// file to be importable from non-Flutter contexts (e.g. pure-Dart
/// tests). Define a local alias to avoid the flutter import here.
typedef VoidCallback = void Function();
