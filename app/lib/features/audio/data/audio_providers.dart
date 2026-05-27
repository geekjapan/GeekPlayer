import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/providers.dart';
import '../domain/audio_track.dart';
import '../domain/play_audio_use_case.dart';
import 'audio_metadata_source.dart';
import 'audio_repository.dart';

part 'audio_providers.g.dart';

@Riverpod(keepAlive: true)
AudioRepository audioRepository(Ref ref) {
  return AudioRepository(
    positionsDao: ref.watch(playbackPositionsDaoProvider),
    recentItemsDao: ref.watch(recentItemsDaoProvider),
  );
}

@Riverpod(keepAlive: true)
AudioMetadataSource audioMetadataSource(Ref ref) => const AudioMetadataSource();

@Riverpod(keepAlive: true)
PlayAudioUseCase playAudioUseCase(Ref ref) =>
    PlayAudioUseCase(ref.watch(audioRepositoryProvider));

/// Reverse-chronological audio recents (kind = 'audio'). Refreshed each
/// time `ref.invalidate(...)` is called from the audio controller after
/// a new track is opened.
@riverpod
Future<List<AudioTrack>> recentAudio(Ref ref) {
  return ref.watch(audioRepositoryProvider).fetchRecentAudioItems();
}
