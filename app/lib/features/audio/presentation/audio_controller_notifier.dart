import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/media/audio_handler.dart';
import '../../../core/media/audio_providers.dart';
import '../../../core/media/media_session.dart';
import '../../../core/media/models.dart';
import '../data/audio_providers.dart';
import '../data/audio_repository.dart';
import '../domain/audio_queue.dart';
import '../domain/audio_track.dart';
import '../domain/play_audio_use_case.dart';

part 'audio_controller_notifier.g.dart';

/// State exposed by [AudioControllerNotifier] to the UI. Carries the
/// session, the queue, and a lightweight snapshot of the current play
/// state so widgets don't all subscribe to the underlying streams.
@immutable
class AudioControllerState {
  const AudioControllerState({
    required this.session,
    required this.queue,
    required this.playState,
    this.position = Duration.zero,
    this.duration,
  });

  final AudioSession session;
  final AudioQueue queue;
  final MediaPlayState playState;
  final Duration position;
  final Duration? duration;

  AudioTrack? get currentTrack => queue.current;

  AudioControllerState copyWith({
    AudioSession? session,
    AudioQueue? queue,
    MediaPlayState? playState,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
  }) {
    return AudioControllerState(
      session: session ?? this.session,
      queue: queue ?? this.queue,
      playState: playState ?? this.playState,
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
    );
  }
}

/// Top-level controller for the audio feature. KeepAlive because the
/// session needs to outlive any single screen — the mini player on the
/// home screen and the full player screen both observe this notifier.
@Riverpod(keepAlive: true)
class AudioController extends _$AudioController {
  StreamSubscription<MediaPlayState>? _playStateSub;
  StreamSubscription<MediaPosition>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<ja.ProcessingState>? _processingStateSub;

  @override
  AudioControllerState? build() {
    ref.onDispose(_disposeStreams);
    return null;
  }

  /// Cancel stream subs only — safe to call from `onDispose` because
  /// it doesn't touch `state` or `ref` after the provider is gone.
  void _disposeStreams() {
    _playStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _processingStateSub?.cancel();
    _playStateSub = null;
    _positionSub = null;
    _durationSub = null;
    _processingStateSub = null;
  }

  /// Begin a new playback session for the given pick result. Replaces
  /// any in-flight session.
  Future<void> startQueue(AudioPickResult pick, {int startIndex = 0}) async {
    await _cleanup();
    final GeekPlayerAudioHandler handler = ref.read(audioHandlerProvider);
    final AudioSession session = AudioSession.usingPlayer(
      handler.player,
      handler: handler,
    );
    final AudioQueue queue = AudioQueue(
      tracks: pick.tracks,
      currentIndex: startIndex.clamp(0, pick.tracks.length - 1),
    );
    state = AudioControllerState(
      session: session,
      queue: queue,
      playState: const MediaPlayState.loading(),
    );
    _wireStreams(session);
    handler.setSkipHandlers(onNext: _onSkipNext, onPrevious: _onSkipPrevious);
    await ref.read(audioRepositoryProvider).recordRecentOpen(pick.sourceUri);
    ref.invalidate(recentAudioProvider);
    await _loadCurrentTrack();
  }

  Future<void> _loadCurrentTrack() async {
    final AudioControllerState? s = state;
    if (s == null) return;
    final AudioTrack? track = s.queue.current;
    if (track == null) return;
    final Duration start = await ref
        .read(playAudioUseCaseProvider)
        .resolveStart(track.uri);
    await s.session.open(track.uriString, startAt: start);
    await s.session.play();
    _updateNowPlayingItem(track);
    // Fire-and-forget metadata read; the UI updates when state changes.
    unawaited(_resolveMetadata(track));
  }

  Future<void> _resolveMetadata(AudioTrack track) async {
    final AudioMetadata md = await ref
        .read(audioMetadataSourceProvider)
        .readMetadata(track.uri);
    final AudioControllerState? s = state;
    if (s == null) return;
    final AudioTrack? current = s.queue.current;
    if (current?.uri != track.uri) return; // queue moved on
    final AudioQueue next = s.queue.withCurrentMetadata(md);
    state = s.copyWith(queue: next);
    final AudioTrack updated = next.current!;
    _updateNowPlayingItem(updated);
  }

  void _updateNowPlayingItem(AudioTrack track) {
    final GeekPlayerAudioHandler? handler = ref.exists(audioHandlerProvider)
        ? ref.read(audioHandlerProvider)
        : null;
    if (handler == null) return;
    handler.updateNowPlaying(
      MediaItem(
        id: track.uriString,
        album: track.effectiveAlbum,
        title: track.effectiveTitle,
        artist: track.effectiveArtist,
        // Artwork is left blank for now — audio_service expects a URI
        // for cross-process delivery and we'd need to write the bytes
        // to a temp file. v0.2 task.
      ),
    );
  }

  void _wireStreams(AudioSession session) {
    _playStateSub = session.playStateStream.listen((MediaPlayState ps) {
      final AudioControllerState? s = state;
      if (s == null) return;
      state = s.copyWith(playState: ps);
    });
    _positionSub = session.positionStream.listen((MediaPosition mp) {
      final AudioControllerState? s = state;
      if (s == null) return;
      state = s.copyWith(position: mp.position);
    });
    _durationSub = session.durationStream.listen((Duration? d) {
      final AudioControllerState? s = state;
      if (s == null) return;
      state = s.copyWith(duration: d, clearDuration: d == null);
      // Re-apply the end-of-playback rule once duration is known.
      if (d != null) {
        final Duration adjusted = PlayAudioUseCase.applyEndOfPlaybackRule(
          s.position,
          d,
        );
        if (adjusted == Duration.zero && s.position > Duration.zero) {
          unawaited(session.seek(Duration.zero));
        }
      }
    });
    // Auto-advance on completion via just_audio's processingState.
    final ja.AudioPlayer? player = session.player;
    if (player != null) {
      _processingStateSub = player.processingStateStream.listen((
        ja.ProcessingState ps,
      ) {
        if (ps == ja.ProcessingState.completed) {
          unawaited(_onTrackCompleted());
        }
      });
    }
  }

  Future<void> _onTrackCompleted() async {
    final AudioControllerState? s = state;
    if (s == null) return;
    // Save the ResumePoint for the just-finished track. The position
    // is at (or near) the duration so the next time the user opens it
    // we resume from 0 (per the end-of-playback rule).
    final AudioTrack? finished = s.queue.current;
    if (finished != null) {
      await ref
          .read(audioRepositoryProvider)
          .saveResumePoint(finished.uri, s.position);
    }
    if (s.queue.repeat == RepeatMode.one) {
      await s.session.seek(Duration.zero);
      await s.session.play();
      return;
    }
    final AudioQueue? next = s.queue.skipNext();
    if (next == null) {
      // End of queue, repeat=none. Pause at end.
      await s.session.pause();
      return;
    }
    state = s.copyWith(queue: next, position: Duration.zero);
    await _loadCurrentTrack();
  }

  Future<void> _onSkipNext() async {
    final AudioControllerState? s = state;
    if (s == null) return;
    if (s.queue.repeat == RepeatMode.one) {
      // Per spec, the user-driven next button advances even when
      // repeat=one (only auto-advance respects repeat=one).
      final AudioQueue advanced = AudioQueue(
        tracks: s.queue.tracks,
        currentIndex: s.queue.currentIndex,
        shuffle: s.queue.shuffle,
        shuffledOrder: s.queue.shuffledOrder,
      );
      final AudioQueue? next = advanced.skipNext();
      if (next == null) return;
      await _saveCurrentPositionFor(s.queue.current);
      state = s.copyWith(queue: next, position: Duration.zero);
      await _loadCurrentTrack();
      return;
    }
    final AudioQueue? next = s.queue.skipNext();
    if (next == null) return;
    await _saveCurrentPositionFor(s.queue.current);
    state = s.copyWith(queue: next, position: Duration.zero);
    await _loadCurrentTrack();
  }

  Future<void> _onSkipPrevious() async {
    final AudioControllerState? s = state;
    if (s == null) return;
    // If the user is already past 3s into the track or this is the
    // first track, the standard "previous" gesture restarts the
    // current track rather than going back.
    if (s.position > const Duration(seconds: 3) ||
        s.queue.shuffledOrder.indexOf(s.queue.currentIndex) == 0) {
      await s.session.seek(Duration.zero);
      return;
    }
    await _saveCurrentPositionFor(s.queue.current);
    final AudioQueue prev = s.queue.skipPrevious();
    state = s.copyWith(queue: prev, position: Duration.zero);
    await _loadCurrentTrack();
  }

  Future<void> _saveCurrentPositionFor(AudioTrack? track) async {
    if (track == null) return;
    final AudioControllerState? s = state;
    if (s == null) return;
    await ref
        .read(audioRepositoryProvider)
        .saveResumePoint(track.uri, s.position);
  }

  // ===== Public UI commands =====

  Future<void> togglePlayPause() async {
    final AudioControllerState? s = state;
    if (s == null) return;
    if (s.playState.isPlaying) {
      await s.session.pause();
    } else {
      await s.session.play();
    }
  }

  Future<void> seek(Duration target) async {
    final AudioControllerState? s = state;
    if (s == null) return;
    await s.session.seek(target);
  }

  Future<void> setSpeed(MediaSpeed speed) async {
    final AudioControllerState? s = state;
    if (s == null) return;
    await s.session.setSpeed(speed);
    state = s.copyWith();
  }

  Future<void> skipNext() => _onSkipNext();
  Future<void> skipPrevious() => _onSkipPrevious();

  void toggleShuffle() {
    final AudioControllerState? s = state;
    if (s == null) return;
    state = s.copyWith(queue: s.queue.toggleShuffle());
  }

  void cycleRepeat() {
    final AudioControllerState? s = state;
    if (s == null) return;
    state = s.copyWith(queue: s.queue.cycleRepeat());
  }

  /// Tear down the previous session before installing a new one.
  /// Called from [startQueue] before constructing a fresh
  /// [AudioSession]. Does **not** run from `ref.onDispose` — that path
  /// only cancels stream subs because `ref` is no longer usable there.
  Future<void> _cleanup() async {
    _disposeStreams();
    final AudioControllerState? s = state;
    if (s == null) return;
    // Persist ResumePoint for the active track before disposal.
    final AudioTrack? current = s.queue.current;
    if (current != null && s.position > Duration.zero) {
      await ref
          .read(audioRepositoryProvider)
          .saveResumePoint(current.uri, s.position);
    }
    await s.session.dispose();
    final GeekPlayerAudioHandler h = ref.read(audioHandlerProvider);
    h.setSkipHandlers();
    await h.clearNowPlaying();
  }
}
