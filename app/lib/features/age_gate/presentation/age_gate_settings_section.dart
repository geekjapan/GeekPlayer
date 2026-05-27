import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/storage/database.dart';
import '../../novel/data/consent_repository.dart';
import '../../novel_narou/data/narou_providers.dart';

/// 「設定」→「オンライン小説」配下に並べる、年齢確認の状態行と
/// 再同意 / 同意取り消しのフロー。
///
/// 仕様 `r18-age-gate` "Settings screen lets users revoke and re-grant
/// consent":
///   - 現状を表示（同意済 (YYYY-MM-DD) / 未同意）
///   - "年齢確認をやり直す" → 確認ダイアログ → revoke
///   - revoke 後 R18 surface は即座に隠れる（`consentForNarou18Provider`
///     のリスナー経由で home section が再描画される）。
class AgeGateSettingsSection extends ConsumerStatefulWidget {
  const AgeGateSettingsSection({super.key});

  @override
  ConsumerState<AgeGateSettingsSection> createState() =>
      _AgeGateSettingsSectionState();
}

class _AgeGateSettingsSectionState
    extends ConsumerState<AgeGateSettingsSection> {
  late Future<SiteConsentRow?> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _loadRow();
  }

  Future<SiteConsentRow?> _loadRow() async {
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    final Map<Site, SiteConsentRow> all = await repo.getAll();
    return all[Site.noc];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SiteConsentRow?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<SiteConsentRow?> snap) {
        final SiteConsentRow? row = snap.data;
        final bool granted = row?.granted ?? false;
        final String stateText = granted
            ? '同意済 (${DateFormat('yyyy-MM-dd').format(row!.decidedAt.toLocal())})'
            : '未同意';
        return Card(
          child: ListTile(
            key: const Key('age-gate-settings-tile'),
            title: const Text('年齢確認をやり直す'),
            subtitle: Text(stateText),
            trailing: const Icon(Icons.refresh),
            onTap: granted ? _confirmAndRevoke : _showInfoNotGranted,
          ),
        );
      },
    );
  }

  Future<void> _confirmAndRevoke() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('年齢確認の取り消し'),
          content: const Text(
            '同意を取り消すと、ノクターン系統の作品リストにアクセスでき'
            'なくなります。後で再度同意することはできます。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop<bool>(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('age-gate-confirm-revoke'),
              onPressed: () => Navigator.of(dialogContext).pop<bool>(true),
              child: const Text('取り消す'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    await repo.revoke(Site.noc);
    // ignore: unused_result
    await ref.read(consentForNarou18Provider.notifier).refresh();
    if (mounted) {
      setState(_reload);
    }
  }

  void _showInfoNotGranted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('現在は未同意です。ノクターン系統のタブをタップすると確認ダイアログが開きます。'),
      ),
    );
  }
}
