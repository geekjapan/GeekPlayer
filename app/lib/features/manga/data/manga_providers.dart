import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/providers.dart';
import '../domain/manga_repository.dart';
import 'manga_repository_impl.dart';

part 'manga_providers.g.dart';

/// Singleton [MangaRepository] backed by the shared [AppDatabase].
@Riverpod(keepAlive: true)
MangaRepository mangaRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return MangaRepositoryImpl(
    metadataDao: db.mangaMetadataDao,
    bookmarksDao: db.mangaBookmarksDao,
    recentItemsDao: db.recentItemsDao,
  );
}
