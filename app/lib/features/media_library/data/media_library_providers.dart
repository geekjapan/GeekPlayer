import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/providers.dart';
import 'media_library_repository.dart';

part 'media_library_providers.g.dart';

/// Singleton [MediaLibraryRepository] backed by the shared [AppDatabase].
@Riverpod(keepAlive: true)
MediaLibraryRepository mediaLibraryRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return MediaLibraryRepository(
    mediaIndexDao: db.mediaIndexDao,
    watchHistoryDao: db.watchHistoryDao,
    favoritesDao: db.favoritesDao,
    playlistsDao: db.playlistsDao,
    playlistItemsDao: db.playlistItemsDao,
  );
}
