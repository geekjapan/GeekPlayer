import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/media/media_session.dart';
import '../../../core/media/models.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/app_settings_notifier.dart';
import '../data/video_providers.dart';
import '../domain/video_file.dart';

part 'video_controller_notifier.g.dart';

/// State held by [VideoControllerNotifier]. We carry both the session
/// itself (so the UI can ask for [VideoSession.videoController]) and the
/// resolved start position used to render the initial seek bar.
class VideoControllerState {
  const VideoControllerState({
    required this.session,
    required this.file,
    required this.initialStart,
  });

  final VideoSession session;
  final VideoFile file;
  final Duration initialStart;
}

/// Owns a [VideoSession] for the lifetime of the player screen. When the
/// screen pops the provider auto-disposes, dispose() runs, and the
/// current playhead is persisted to [PlaybackPositionsDao].
@riverpod
class VideoControllerNotifier extends _$VideoControllerNotifier {
  @override
  Future<VideoControllerState> build(VideoFile file) async {
    final session = VideoSession();
    final start = await ref
        .read(playVideoUseCaseProvider)
        .resolveStart(file.uri);
    await ref.read(videoRepositoryProvider).recordRecentOpen(file.uri);
    // Invalidate the recent list so the home screen reflects the new entry.
    ref.invalidate(recentVideosProvider);

    // Lock the saved position into [`session.open`] so the libmpv handle
    // seeks before the first frame is shown.
    await session.open(file.uriString, startAt: start);

    // Apply the default playback speed from AppSettings before the first
    // frame plays. Per add-app-settings spec Requirement "Playback section
    // sets default playback speed", a NEW session adopts the default; a
    // session that is already playing is untouched (we are still in
    // build() so this is the new-session branch).
    final AppSettings? settings = ref
        .read(appSettingsProvider)
        .value;
    if (settings != null && settings.defaultPlaybackSpeed != 1.0) {
      await session.setSpeed(MediaSpeed(settings.defaultPlaybackSpeed));
    }

    await session.play();

    ref.onDispose(() async {
      try {
        final Duration current = session.currentPosition;
        if (current > Duration.zero) {
          await ref
              .read(videoRepositoryProvider)
              .saveResumePoint(file.uri, current);
        }
      } finally {
        await session.dispose();
      }
    });

    return VideoControllerState(
      session: session,
      file: file,
      initialStart: start,
    );
  }

  /// Cycle play/pause based on the current state stream's last value.
  Future<void> togglePlayPause(MediaPlayState lastState) async {
    final VideoSession? session = state.value?.session;
    if (session == null) return;
    if (lastState.isPlaying) {
      await session.pause();
    } else {
      await session.play();
    }
  }

  Future<void> seek(Duration position) async {
    final VideoSession? session = state.value?.session;
    if (session == null) return;
    await session.seek(position);
  }

  Future<void> setSpeed(MediaSpeed speed) async {
    final VideoSession? session = state.value?.session;
    if (session == null) return;
    await session.setSpeed(speed);
  }

  Future<bool> toggleSubtitle() async {
    final VideoSession? session = state.value?.session;
    if (session == null) return false;
    return session.toggleSubtitle();
  }
}
