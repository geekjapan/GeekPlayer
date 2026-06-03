import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../l10n/app_localizations.dart';
import '../../library/home_section.dart';
import '../data/media_library_providers.dart';
import '../data/media_library_repository.dart';
import '../domain/media_item.dart';

part 'media_library_home_section.g.dart';

/// Reserved order = 700 per ADR-0004 (v0.2 Media Library section).
class MediaLibraryHomeSection implements HomeSection {
  const MediaLibraryHomeSection();

  @override
  String get id => 'media_library';

  @override
  int get order => 700;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MediaLibraryHomeSectionBody();
  }
}

@Riverpod(keepAlive: true)
List<HomeSection> mediaLibraryHomeSections(Ref ref) {
  return const <HomeSection>[MediaLibraryHomeSection()];
}

class _MediaLibraryHomeSectionBody extends ConsumerWidget {
  const _MediaLibraryHomeSectionBody();

  Future<void> _scanFolder(BuildContext context, WidgetRef ref) async {
    // For MVP: prompt the user to enter a path via a simple dialog.
    final String? path = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _FolderPathDialog(),
    );
    if (path == null || path.isEmpty) return;
    if (!context.mounted) return;

    final MediaLibraryRepository repo = ref.read(
      mediaLibraryRepositoryProvider,
    );
    final int count = await repo.scanFolder(path);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.mediaLibraryScanResult(count),
        ),
      ),
    );
    // Invalidate recent list.
    ref.invalidate(_recentMediaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final AsyncValue<List<WatchHistoryEntry>> recentAsync = ref.watch(
      _recentMediaProvider,
    );
    final AsyncValue<int> favCountAsync = ref.watch(_favoritesCountProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.mediaLibrarySectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              favCountAsync.maybeWhen(
                data: (int count) => count > 0
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Chip(
                          avatar: const Icon(Icons.star, size: 16),
                          label: Text('$count'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open),
                tooltip: l10n.mediaLibraryScanTooltip,
                onPressed: () => _scanFolder(context, ref),
              ),
            ],
          ),
          recentAsync.when(
            data: (List<WatchHistoryEntry> recent) {
              if (recent.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    l10n.mediaLibrarySectionEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  separatorBuilder: (BuildContext context2, int index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (BuildContext ctx, int i) {
                    return _RecentMediaTile(entry: recent[i]);
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
Future<List<WatchHistoryEntry>> _recentMedia(Ref ref) async {
  return ref.watch(mediaLibraryRepositoryProvider).listRecent(limit: 20);
}

@riverpod
Future<int> _favoritesCount(Ref ref) async {
  final List<FavoriteItem> favs = await ref
      .watch(mediaLibraryRepositoryProvider)
      .listFavorites();
  return favs.length;
}

class _RecentMediaTile extends StatelessWidget {
  const _RecentMediaTile({required this.entry});
  final WatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                entry.uri.endsWith('.mp3') ||
                        entry.uri.endsWith('.flac') ||
                        entry.uri.endsWith('.aac') ||
                        entry.uri.endsWith('.wav') ||
                        entry.uri.endsWith('.ogg') ||
                        entry.uri.endsWith('.m4a') ||
                        entry.uri.endsWith('.opus')
                    ? Icons.audiotrack
                    : Icons.movie,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.uri.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Simple dialog that lets the user type a folder path for scanning.
class _FolderPathDialog extends StatefulWidget {
  const _FolderPathDialog();

  @override
  State<_FolderPathDialog> createState() => _FolderPathDialogState();
}

class _FolderPathDialogState extends State<_FolderPathDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.mediaLibraryScanDialogTitle),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(hintText: l10n.mediaLibraryScanDialogHint),
        autofocus: true,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.mediaLibraryScanDialogConfirm),
        ),
      ],
    );
  }
}
