import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/home_section.dart';
import '../data/manga_providers.dart';
import '../domain/manga_archive.dart';
import '../domain/manga_metadata.dart';
import 'manga_viewer_screen.dart';

part 'manga_home_section.g.dart';

/// Reserved order = 600 per ADR-0004 (v0.2 Manga section).
class MangaHomeSection implements HomeSection {
  const MangaHomeSection();

  @override
  String get id => 'manga';

  @override
  int get order => 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MangaHomeSectionBody();
  }
}

@Riverpod(keepAlive: true)
List<HomeSection> mangaHomeSections(Ref ref) {
  return const <HomeSection>[MangaHomeSection()];
}

class _MangaHomeSectionBody extends ConsumerWidget {
  const _MangaHomeSectionBody();

  Future<void> _pickAndOpen(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['zip', 'cbz'],
    );
    if (result == null || result.files.isEmpty) return;
    final String? path = result.files.first.path;
    if (path == null) return;

    MangaArchive archive;
    try {
      archive = await ref.read(mangaRepositoryProvider).openArchive(path);
    } on AppError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => MangaViewerScreen(archive: archive),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final AsyncValue<List<MangaMetadata>> recentAsync = ref.watch(
      _recentMangaProvider,
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
                  l10n.mangaHomeSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.mangaHomeSectionAddTooltip,
                onPressed: () => _pickAndOpen(context, ref),
              ),
            ],
          ),
          recentAsync.when(
            data: (List<MangaMetadata> manga) {
              if (manga.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    l10n.mangaHomeSectionEmpty,
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
                  itemCount: manga.length,
                  separatorBuilder: (BuildContext ctx2, int idx2) =>
                      const SizedBox(width: 8),
                  itemBuilder: (BuildContext ctx, int i) {
                    return _MangaTile(meta: manga[i]);
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
Future<List<MangaMetadata>> _recentManga(Ref ref) async {
  return ref.watch(mangaRepositoryProvider).listRecentManga();
}

class _MangaTile extends ConsumerWidget {
  const _MangaTile({required this.meta});
  final MangaMetadata meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        MangaArchive archive;
        try {
          archive = await ref
              .read(mangaRepositoryProvider)
              .openArchive(meta.path);
        } on AppError catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
          return;
        }
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext ctx) => MangaViewerScreen(archive: archive),
          ),
        );
      },
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
              child: const Center(child: Icon(Icons.auto_stories, size: 32)),
            ),
            const SizedBox(height: 4),
            Text(
              meta.title,
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
