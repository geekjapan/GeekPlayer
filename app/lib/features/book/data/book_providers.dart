import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/providers.dart';
import '../domain/book_repository.dart';
import 'book_repository_impl.dart';

part 'book_providers.g.dart';

/// Singleton [BookRepository] backed by the shared [AppDatabase].
@Riverpod(keepAlive: true)
BookRepository bookRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return BookRepositoryImpl(
    metadataDao: db.bookMetadataDao,
    bookmarksDao: db.bookBookmarksDao,
    recentItemsDao: db.recentItemsDao,
  );
}
