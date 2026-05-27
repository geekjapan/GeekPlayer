import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/providers.dart';
import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// ライブラリ section — recent-items cap + history clear (spec
/// Requirement "Library section caps recent items and supports history
/// clear"). Lowering the cap does NOT delete entries immediately; the
/// home screen prunes on next render (see HomeScreen integration).
class LibrarySection extends ConsumerWidget {
  const LibrarySection({super.key});

  static const List<int> capChoices = <int>[10, 25, 50, 100];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int current = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.recentItemsCap ?? 50,
      ),
    );

    return SettingsSection(
      id: 'library',
      title: 'ライブラリ',
      children: <Widget>[
        ListTile(
          key: const Key('recent-items-cap'),
          title: const Text('"最近開いた" の上限'),
          subtitle: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final int c in capChoices)
                ChoiceChip(
                  key: Key('cap-$c'),
                  label: Text('$c'),
                  selected: current == c,
                  onSelected: (bool sel) {
                    if (!sel) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .mutate(
                          (AppSettings s) => s.copyWith(recentItemsCap: c),
                        );
                  },
                ),
            ],
          ),
        ),
        ListTile(
          key: const Key('clear-history'),
          title: const Text('履歴をすべてクリア'),
          trailing: const Icon(Icons.delete_sweep_outlined),
          onTap: () => _confirmClear(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        key: const Key('clear-history-confirm'),
        title: const Text('履歴をすべて削除しますか?'),
        content: const Text('この操作は取り消せません。'),
        actions: <Widget>[
          TextButton(
            key: const Key('clear-history-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('clear-history-confirm-button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final dao = ref.read(recentItemsDaoProvider);
    // RecentItemsDao doesn't expose a wipe-all helper; delete by kind.
    for (final String k in const <String>['video', 'audio', 'novel']) {
      await dao.pruneOlderThan(k, 0);
    }
  }
}
