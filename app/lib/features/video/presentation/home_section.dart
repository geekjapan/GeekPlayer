import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../data/video_providers.dart';
import '../data/video_repository.dart';
import '../domain/video_file.dart';
import 'player_screen.dart';

/// "Video" portion of the home screen. Rendered by [VideoHomeSection]
/// via the [HomeScreen] section registry (ADR-0004). Provides the
/// "動画を開く" call-to-action and the reverse-chronological recent list.
class VideoHomeSectionBody extends ConsumerWidget {
  const VideoHomeSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<VideoFile>> recent = ref.watch(recentVideosProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.movie_outlined),
                const SizedBox(width: 8),
                Text('動画', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _onOpenPressed(context, ref),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('動画を開く'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('最近開いた', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            recent.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, StackTrace st) => _ErrorRow(
                message: ErrorMessages.localize(UnknownError(e), context),
              ),
              data: (List<VideoFile> items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('最近開いた動画はまだありません'),
                  );
                }
                return _RecentList(items: items);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onOpenPressed(BuildContext context, WidgetRef ref) async {
    final VideoRepository repo = ref.read(videoRepositoryProvider);
    final VideoFile? picked = await repo.pickFile();
    if (picked == null) return; // user cancelled
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => PlayerScreen(file: picked)));
    // Refresh the recent list on return.
    ref.invalidate(recentVideosProvider);
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList({required this.items});
  final List<VideoFile> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (BuildContext _, int _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final VideoFile f = items[i];
        return ListTile(
          dense: true,
          key: ValueKey<String>('recent.video.${f.uriString}'),
          leading: const Icon(Icons.play_circle_outline),
          title: Text(f.displayName, overflow: TextOverflow.ellipsis),
          onTap: () => _onRecentTapped(context, ref, f),
        );
      },
    );
  }

  Future<void> _onRecentTapped(
    BuildContext context,
    WidgetRef ref,
    VideoFile f,
  ) async {
    final VideoRepository repo = ref.read(videoRepositoryProvider);
    final bool exists = await repo.fileExists(f.uri);
    if (!exists) {
      await repo.forgetStaleEntry(f.uri);
      ref.invalidate(recentVideosProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルが見つかりません: ${f.displayName}')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => PlayerScreen(file: f)));
    ref.invalidate(recentVideosProvider);
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
