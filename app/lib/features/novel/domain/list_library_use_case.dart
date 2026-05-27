import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../data/library_repository.dart';

part 'list_library_use_case.g.dart';

/// List the user's Library, optionally filtered by [Site].
///
/// Spec `online-novel-library` scenario "Site filter chips narrow the
/// listing": `NovelHomeSection` calls this with a chip-derived
/// `Site?` argument; `null` returns everything newest-first.
class ListLibraryUseCase {
  ListLibraryUseCase(this._library);

  final LibraryRepository _library;

  Future<List<Work>> call({Site? site}) {
    return _library.listLibrary(site: site);
  }
}

@Riverpod(keepAlive: true)
ListLibraryUseCase listLibraryUseCase(Ref ref) {
  return ListLibraryUseCase(ref.watch(libraryRepositoryProvider));
}
