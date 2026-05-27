import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/providers.dart';
import '../domain/play_video_use_case.dart';
import '../domain/video_file.dart';
import 'video_repository.dart';

part 'video_providers.g.dart';

@Riverpod(keepAlive: true)
VideoRepository videoRepository(Ref ref) {
  return VideoRepository(
    positionsDao: ref.watch(playbackPositionsDaoProvider),
    recentItemsDao: ref.watch(recentItemsDaoProvider),
  );
}

@Riverpod(keepAlive: true)
PlayVideoUseCase playVideoUseCase(Ref ref) {
  return PlayVideoUseCase(ref.watch(videoRepositoryProvider));
}

/// Reverse-chronological list of recently opened videos, refreshed each
/// time the home screen rebuilds.
@riverpod
Future<List<VideoFile>> recentVideos(Ref ref) {
  return ref.watch(videoRepositoryProvider).fetchRecentItems();
}
