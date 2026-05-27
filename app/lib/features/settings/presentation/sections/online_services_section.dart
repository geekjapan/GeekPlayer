import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/novel/models/site.dart';
import '../../../../core/storage/database.dart';
import '../../../../core/storage/providers.dart';
import '../../../novel/data/consent_repository.dart';
import '../settings_screen.dart';

/// オンラインサービス section — per-site consent toggles + ADR-0001
/// §注意書き-3 permanent disclosure + cache-deletion confirmation on
/// revoke. Spec Requirement "Online services section surfaces consent
/// toggles and cache deletion prompt".
class OnlineServicesSection extends ConsumerStatefulWidget {
  const OnlineServicesSection({super.key});

  @override
  ConsumerState<OnlineServicesSection> createState() =>
      _OnlineServicesSectionState();
}

class _OnlineServicesSectionState
    extends ConsumerState<OnlineServicesSection> {
  Future<Map<Site, bool>>? _granted;

  @override
  void initState() {
    super.initState();
    _granted = _load();
  }

  Future<Map<Site, bool>> _load() async {
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    final Map<Site, bool> out = <Site, bool>{};
    for (final Site s in Site.values) {
      out[s] = await repo.hasFreshConsent(s);
    }
    return out;
  }

  void _refresh() => setState(() => _granted = _load());

  Future<int> _bodyBytesForSite(Site site) async {
    final AppDatabase db = ref.read(appDatabaseProvider);
    final res = await db.customSelect(
      'SELECT COALESCE(SUM(LENGTH(body)), 0) AS total '
      'FROM novel_episodes WHERE site = ?',
      variables: <Variable<Object>>[Variable<String>(site.code)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{db.novelEpisodes},
    ).getSingle();
    return res.read<int>('total');
  }

  Future<void> _toggle(Site site, bool nextValue) async {
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    if (nextValue) {
      await repo.grant(site);
      _refresh();
      return;
    }
    // Revoking: always proceed with the consent flip, but offer the
    // optional cache wipe.
    await repo.revoke(site);
    if (!mounted) return;
    final int bytes = await _bodyBytesForSite(site);
    final double mb = bytes / (1024.0 * 1024.0);
    if (!mounted) {
      _refresh();
      return;
    }
    final bool? wipe = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        key: Key('revoke-cache-${site.code}'),
        content: Text('本文キャッシュ (${mb.toStringAsFixed(1)} MB) も削除しますか?'),
        actions: <Widget>[
          TextButton(
            key: Key('revoke-keep-${site.code}'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('残す'),
          ),
          FilledButton(
            key: Key('revoke-delete-${site.code}'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (wipe == true) {
      final db = ref.read(appDatabaseProvider);
      await (db.delete(db.novelEpisodes)
            ..where(($NovelEpisodesTable t) => t.site.equals(site.code)))
          .go();
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      id: 'online-services',
      title: 'オンラインサービス',
      children: <Widget>[
        const Padding(
          key: Key('online-services-disclosure'),
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            // ADR-0001 §注意書き-3 (permanent disclosure).
            '本アプリは個人利用目的でなろう / ノクターン系 / カクヨムから '
            '本文を取得します。各サイトの利用規約に同意した範囲でのみ '
            '利用してください。',
          ),
        ),
        FutureBuilder<Map<Site, bool>>(
          future: _granted,
          builder: (BuildContext ctx, AsyncSnapshot<Map<Site, bool>> snap) {
            if (!snap.hasData) {
              return const ListTile(subtitle: LinearProgressIndicator());
            }
            return Column(
              children: <Widget>[
                for (final Site s in Site.values)
                  SwitchListTile(
                    key: Key('consent-${s.code}'),
                    title: Text(s.displayName),
                    value: snap.data![s] ?? false,
                    onChanged: (bool v) => _toggle(s, v),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
