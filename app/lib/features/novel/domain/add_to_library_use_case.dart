import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/novel_repository.dart';
import '../data/library_repository.dart';

part 'add_to_library_use_case.g.dart';

/// "Library に追加" use case.
///
/// Spec `online-novel-library` "Library add flow (active caching)":
/// the only legitimate write path into `novel_works` / `novel_episodes`.
/// Delegates to [LibraryRepository.addToLibrary] which is idempotent
/// and resume-safe.
class AddToLibraryUseCase {
  AddToLibraryUseCase(this._library);

  final LibraryRepository _library;

  Future<void> call(
    NovelRepository source,
    WorkId workId, {
    void Function(int fetched, int total)? onProgress,
  }) {
    return _library.addToLibrary(source, workId, onProgress: onProgress);
  }
}

@Riverpod(keepAlive: true)
AddToLibraryUseCase addToLibraryUseCase(Ref ref) {
  return AddToLibraryUseCase(ref.watch(libraryRepositoryProvider));
}
