import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/database.dart';
import '../../../../core/storage/providers.dart';
import '../../domain/app_settings.dart';
import '../app_settings_notifier.dart';
import '../settings_screen.dart';

/// キャッシュ section — shows total novel cache size, optional MB cap,
/// per-site clear, "すべてクリア" destructive, and "古い順に削除"
/// helper when over the cap. Spec Requirement "Cache section shows size
/// and supports clearing".
class CacheSection extends ConsumerStatefulWidget {
  const CacheSection({super.key});

  @override
  ConsumerState<CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends ConsumerState<CacheSection> {
  Future<int>? _sizeBytes;

  @override
  void initState() {
    super.initState();
    _sizeBytes = _computeSizeBytes();
  }

  Future<int> _computeSizeBytes() async {
    final AppDatabase db = ref.read(appDatabaseProvider);
    // SUM(LENGTH(body)) — matches design D8.
    final res = await db
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(body)), 0) AS total FROM novel_episodes',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            db.novelEpisodes,
          },
        )
        .getSingle();
    return res.read<int>('total');
  }

  void _refresh() {
    final Future<int> next = _computeSizeBytes();
    setState(() {
      _sizeBytes = next;
    });
  }

  Future<void> _clearSite(String site) async {
    final db = ref.read(appDatabaseProvider);
    await (db.delete(
      db.novelEpisodes,
    )..where(($NovelEpisodesTable t) => t.site.equals(site))).go();
    _refresh();
  }

  Future<void> _clearAll() async {
    final db = ref.read(appDatabaseProvider);
    await db.delete(db.novelEpisodes).go();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final int? capMb = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.novelCacheCapMb,
      ),
    );

    return SettingsSection(
      id: 'cache',
      title: 'キャッシュ',
      children: <Widget>[
        FutureBuilder<int>(
          key: const Key('cache-size'),
          future: _sizeBytes,
          builder: (BuildContext ctx, AsyncSnapshot<int> snap) {
            if (!snap.hasData) {
              return const ListTile(
                title: Text('キャッシュサイズ'),
                subtitle: LinearProgressIndicator(),
              );
            }
            final double mb = snap.data! / (1024.0 * 1024.0);
            final bool over = capMb != null && mb > capMb;
            return Column(
              children: <Widget>[
                ListTile(
                  title: const Text('キャッシュサイズ'),
                  trailing: Text('${mb.toStringAsFixed(1)} MB'),
                ),
                if (over)
                  Container(
                    key: const Key('cache-over-banner'),
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Expanded(child: Text('キャッシュが上限を超えています')),
                        TextButton(
                          key: const Key('cache-delete-oldest'),
                          onPressed: () => _deleteOldestUntilUnderCap(),
                          child: const Text('古い順に削除'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        ListTile(
          key: const Key('cache-cap-mb'),
          title: const Text('キャッシュ上限 (MB)'),
          subtitle: Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const Key('cache-cap-unlimited'),
                label: const Text('無制限'),
                selected: capMb == null,
                onSelected: (_) => ref
                    .read(appSettingsProvider.notifier)
                    .mutate(
                      (AppSettings s) => s.copyWith(novelCacheCapMb: null),
                    ),
              ),
              for (final int c in const <int>[100, 500, 1000, 5000])
                ChoiceChip(
                  key: Key('cache-cap-$c'),
                  label: Text('$c'),
                  selected: capMb == c,
                  onSelected: (bool sel) {
                    if (!sel) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .mutate(
                          (AppSettings s) => s.copyWith(novelCacheCapMb: c),
                        );
                  },
                ),
            ],
          ),
        ),
        for (final String site in const <String>['narou', 'noc', 'kakuyomu'])
          ListTile(
            key: Key('cache-clear-$site'),
            title: Text('${_siteLabel(site)} のキャッシュをクリア'),
            trailing: const Icon(Icons.delete_outline),
            onTap: () => _confirmAndClear(
              context,
              title: '${_siteLabel(site)} のキャッシュを削除しますか?',
              run: () => _clearSite(site),
            ),
          ),
        ListTile(
          key: const Key('cache-clear-all'),
          title: const Text('すべてクリア'),
          trailing: const Icon(Icons.delete_sweep),
          onTap: () => _confirmAndClear(
            context,
            title: 'すべての本文キャッシュを削除しますか?',
            run: _clearAll,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndClear(
    BuildContext context, {
    required String title,
    required Future<void> Function() run,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: const Text('この操作は取り消せません。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await run();
  }

  Future<void> _deleteOldestUntilUnderCap() async {
    final int? capMb = ref.read(appSettingsProvider).value?.novelCacheCapMb;
    if (capMb == null) return;
    final int capBytes = capMb * 1024 * 1024;
    final db = ref.read(appDatabaseProvider);
    final List<NovelEpisodeRow> rows =
        await (db.select(
              db.novelEpisodes,
            )..orderBy(<OrderClauseGenerator<$NovelEpisodesTable>>[
              ($NovelEpisodesTable t) =>
                  OrderingTerm(expression: t.fetchedAt, mode: OrderingMode.asc),
            ]))
            .get();
    int total = await _computeSizeBytes();
    for (final NovelEpisodeRow row in rows) {
      if (total <= capBytes) break;
      await (db.delete(db.novelEpisodes)..where(
            ($NovelEpisodesTable t) =>
                t.site.equals(row.site) &
                t.externalId.equals(row.externalId) &
                t.episodeIndex.equals(row.episodeIndex),
          ))
          .go();
      total -= row.body.length;
    }
    _refresh();
  }

  String _siteLabel(String code) => switch (code) {
    'narou' => '小説家になろう',
    'noc' => 'ノクターン系',
    'kakuyomu' => 'カクヨム',
    _ => code,
  };
}
