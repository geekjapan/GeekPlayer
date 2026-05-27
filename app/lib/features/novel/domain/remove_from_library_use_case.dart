import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/novel/models/work_id.dart';
import '../data/library_repository.dart';

part 'remove_from_library_use_case.g.dart';

/// "Library から削除" use case.
///
/// Spec `online-novel-library` scenario "Removing from Library deletes
/// cached bodies": cascade-deletes `novel_works`, `novel_episodes`,
/// and `novel_bookmarks` in a single transaction.
class RemoveFromLibraryUseCase {
  RemoveFromLibraryUseCase(this._library);

  final LibraryRepository _library;

  Future<void> call(WorkId workId) {
    return _library.removeFromLibrary(workId);
  }
}

@Riverpod(keepAlive: true)
RemoveFromLibraryUseCase removeFromLibraryUseCase(Ref ref) {
  return RemoveFromLibraryUseCase(ref.watch(libraryRepositoryProvider));
}
