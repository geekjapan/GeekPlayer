import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/novel/models/episode.dart';
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/novel_repository.dart';
import '../../novel/data/library_repository.dart';
import '../data/narou_providers.dart';
import '../domain/narou_work_summary.dart';
import 'narou_ruby_parser.dart';
import 'reader_screen.dart';

/// 作品詳細画面。タイトル / 著者 / あらすじ (ルビ描画) / タグ / 文字数 /
/// 話数 / 最終更新 / エピソード一覧 / Library 追加ボタンを表示。
class NarouWorkDetailScreen extends ConsumerWidget {
  const NarouWorkDetailScreen({super.key, required this.summary});

  final NarouWorkSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final NarouRubyParser ruby = const NarouRubyParser();
    // Short works report generalAllNo == 0 but still have one episode.
    final int episodeCount = summary.isShort ? 1 : summary.generalAllNo;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          summary.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText.rich(
                  TextSpan(
                    children: ruby.parse(
                      summary.title,
                      baseStyle: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(summary.writer, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                Text('あらすじ', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText.rich(
                  TextSpan(
                    children: ruby.parse(
                      summary.story,
                      baseStyle: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (summary.keywords.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      for (final String k in summary.keywords)
                        Chip(
                          label: Text(k),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text('文字数: ${summary.length}'),
                Text('話数: ${summary.generalAllNo}'),
                if (summary.lastUp != null)
                  Text(
                    '最終更新: ${DateFormat('yyyy-MM-dd HH:mm').format(summary.lastUp!.toLocal())}',
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('narou-add-to-library'),
                  onPressed: () => _confirmAddToLibrary(context, ref),
                  icon: const Icon(Icons.library_add),
                  label: const Text('Library に追加'),
                ),
                const SizedBox(height: 16),
                Text('エピソード', style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          for (int i = 1; i <= episodeCount; i++)
            ListTile(
              key: ValueKey<String>('narou-episode-row-$i'),
              title: Text('第$i話'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NarouReaderScreen(
                      workId: WorkId(
                        site: summary.site,
                        externalId: summary.ncode,
                      ),
                      initialEpisode: EpisodeId(i),
                      title: summary.title,
                      totalEpisodes: episodeCount,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAddToLibrary(BuildContext context, WidgetRef ref) async {
    final int episodes = summary.isShort ? 1 : summary.generalAllNo;
    final int minutes = (episodes / 60).ceil();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Library に追加'),
        content: Text('本作品は $episodes 話あります。\n約 $minutes 分かかります。続行しますか?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop<bool>(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('narou-confirm-add'),
            onPressed: () => Navigator.of(dialogContext).pop<bool>(true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // 一般 / R18 の repository を選ぶ。site が Site.noc なら R18。
    final NovelRepository repo = summary.site == Site.noc
        ? await ref.read(narouR18NovelRepositoryProvider.future)
        : await ref.read(narouNovelRepositoryProvider.future);
    final LibraryRepository lib = ref.read(libraryRepositoryProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Library に追加中…')));
    try {
      await lib.addToLibrary(
        repo,
        WorkId(site: summary.site, externalId: summary.ncode),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Library に追加しました')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('追加に失敗しました: $e')));
      }
    }
  }
}
