import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../l10n/app_localizations.dart';
import '../../library/home_section.dart';
import '../data/book_providers.dart';
import '../domain/book_metadata.dart';
import 'book_reader_screen.dart';

part 'book_home_section.g.dart';

/// Reserved order = 500 per ADR-0004 (v0.2 Book section).
class BookHomeSection implements HomeSection {
  const BookHomeSection();

  @override
  String get id => 'book';

  @override
  int get order => 500;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _BookHomeSectionBody();
  }
}

@Riverpod(keepAlive: true)
List<HomeSection> bookHomeSections(Ref ref) {
  return const <HomeSection>[BookHomeSection()];
}

class _BookHomeSectionBody extends ConsumerWidget {
  const _BookHomeSectionBody();

  Future<void> _pickAndOpen(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'epub'],
    );
    if (result == null || result.files.isEmpty) return;
    final String? path = result.files.first.path;
    if (path == null) return;

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => BookReaderScreen(filePath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final AsyncValue<List<BookMetadata>> recentAsync = ref.watch(
      _recentBooksProvider,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.bookHomeSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.bookHomeSectionAddTooltip,
                onPressed: () => _pickAndOpen(context, ref),
              ),
            ],
          ),
          recentAsync.when(
            data: (List<BookMetadata> books) {
              if (books.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    l10n.bookHomeSectionEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext ctx, int i) {
                    return _BookTile(book: books[i]);
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

@riverpod
Future<List<BookMetadata>> _recentBooks(Ref ref) async {
  return ref.watch(bookRepositoryProvider).listRecentBooks();
}

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book});
  final BookMetadata book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext ctx) => BookReaderScreen(filePath: book.path),
        ),
      ),
      child: SizedBox(
        width: 72,
        child: Column(
          children: <Widget>[
            Container(
              width: 64,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(
                  book.format.name == 'epub'
                      ? Icons.menu_book
                      : Icons.picture_as_pdf,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
