import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/database.dart';
import '../../../../core/storage/providers.dart';
import '../../../../l10n/app_localizations.dart';
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final int? capMb = ref.watch(
      appSettingsProvider.select(
        (AsyncValue<AppSettings> s) => s.value?.novelCacheCapMb,
      ),
    );

    return SettingsSection(
      id: 'cache',
      title: l10n.settingsSectionCache,
      children: <Widget>[
        FutureBuilder<int>(
          key: const Key('cache-size'),
          future: _sizeBytes,
          builder: (BuildContext ctx, AsyncSnapshot<int> snap) {
            if (!snap.hasData) {
              return ListTile(
                title: Text(l10n.settingsCacheSizeLabel),
                subtitle: const LinearProgressIndicator(),
              );
            }
            final double mb = snap.data! / (1024.0 * 1024.0);
            final bool over = capMb != null && mb > capMb;
            return Column(
              children: <Widget>[
                ListTile(
                  title: Text(l10n.settingsCacheSizeLabel),
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
                        Expanded(child: Text(l10n.settingsCacheOverBanner)),
                        TextButton(
                          key: const Key('cache-delete-oldest'),
                          onPressed: () => _deleteOldestUntilUnderCap(),
                          child: Text(l10n.settingsCacheDeleteOldest),
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
          title: Text(l10n.settingsCacheCapMb),
          subtitle: Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const Key('cache-cap-unlimited'),
                label: Text(l10n.settingsCacheCapUnlimited),
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
            title: Text(l10n.settingsCacheClearSite(_siteLabel(l10n, site))),
            trailing: const Icon(Icons.delete_outline),
            onTap: () => _confirmAndClear(
              context,
              l10n: l10n,
              title: l10n.settingsCacheClearSiteConfirmTitle(
                _siteLabel(l10n, site),
              ),
              run: () => _clearSite(site),
            ),
          ),
        ListTile(
          key: const Key('cache-clear-all'),
          title: Text(l10n.settingsCacheClearAll),
          trailing: const Icon(Icons.delete_sweep),
          onTap: () => _confirmAndClear(
            context,
            l10n: l10n,
            title: l10n.settingsCacheClearAllConfirmTitle,
            run: _clearAll,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndClear(
    BuildContext context, {
    required AppLocalizations l10n,
    required String title,
    required Future<void> Function() run,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(l10n.settingsClearHistoryIrreversible),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionDelete),
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

  String _siteLabel(AppLocalizations l10n, String code) => switch (code) {
    'narou' => '小説家になろう',
    'noc' => 'ノクターン系',
    'kakuyomu' => 'カクヨム',
    _ => code,
  };
}
