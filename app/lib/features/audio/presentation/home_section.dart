import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/audio_providers.dart';
import '../data/audio_repository.dart';
import '../domain/audio_track.dart';
import 'audio_controller_notifier.dart';
import 'player_screen.dart';

/// "音楽" portion of the home screen. Rendered by [AudioHomeSection]
/// via the [HomeScreen] section registry (ADR-0004). Provides the
/// "音楽を開く" / "フォルダを開く" CTAs and the recent list.
class AudioHomeSectionBody extends ConsumerWidget {
  const AudioHomeSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AudioTrack>> recent = ref.watch(recentAudioProvider);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.music_note_outlined),
                const SizedBox(width: 8),
                Text('音楽', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _onOpenFolderPressed(context, ref),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('フォルダを開く'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _onOpenFilePressed(context, ref),
                      icon: const Icon(Icons.audio_file),
                      label: const Text('音楽を開く'),
                    ),
                  ],
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
              error: (Object e, StackTrace st) =>
                  _ErrorRow(message: '読み込みに失敗しました: $e'),
              data: (List<AudioTrack> items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('最近開いた音楽はまだありません'),
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

  Future<void> _onOpenFilePressed(BuildContext context, WidgetRef ref) async {
    final AudioRepository repo = ref.read(audioRepositoryProvider);
    final AudioPickResult? pick = await repo.pickFileOrFolder();
    if (pick == null || pick.isEmpty) return;
    if (!context.mounted) return;
    await ref.read(audioControllerProvider.notifier).startQueue(pick);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AudioPlayerScreen()));
  }

  Future<void> _onOpenFolderPressed(BuildContext context, WidgetRef ref) async {
    final AudioRepository repo = ref.read(audioRepositoryProvider);
    final AudioPickResult? pick = await repo.pickFolder();
    if (pick == null || pick.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('再生可能な音楽ファイルが見つかりません')));
      }
      return;
    }
    if (!context.mounted) return;
    await ref.read(audioControllerProvider.notifier).startQueue(pick);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AudioPlayerScreen()));
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList({required this.items});
  final List<AudioTrack> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (BuildContext _, int _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final AudioTrack t = items[i];
        return ListTile(
          dense: true,
          key: ValueKey<String>('recent.audio.${t.uriString}'),
          leading: const Icon(Icons.music_note),
          title: Text(t.displayName, overflow: TextOverflow.ellipsis),
          onTap: () => _onRecentTapped(context, ref, t),
        );
      },
    );
  }

  Future<void> _onRecentTapped(
    BuildContext context,
    WidgetRef ref,
    AudioTrack t,
  ) async {
    final AudioRepository repo = ref.read(audioRepositoryProvider);
    final bool exists = await repo.sourceExists(t.uri);
    if (!exists) {
      await repo.forgetStaleEntry(t.uri);
      ref.invalidate(recentAudioProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルが見つかりません: ${t.displayName}')),
        );
      }
      return;
    }
    AudioPickResult? pick;
    if (t.uri.scheme == 'file' && t.uri.path.endsWith('/')) {
      // Recent entry is a folder URI; re-expand.
      pick = await repo.expandFolderToQueue(t.uri.toFilePath());
    } else {
      pick = AudioPickResult(tracks: <AudioTrack>[t], sourceUri: t.uri);
    }
    if (pick == null || pick.isEmpty) return;
    if (!context.mounted) return;
    await ref.read(audioControllerProvider.notifier).startQueue(pick);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AudioPlayerScreen()));
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
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
