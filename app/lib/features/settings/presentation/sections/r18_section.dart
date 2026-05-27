import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/novel/models/site.dart';
import '../../../novel/data/consent_repository.dart';
import '../settings_screen.dart';

/// R18 section — display current state + age-gate reset.
///
/// Per spec Requirement "R18 section provides age-gate reset" this
/// dispatches a revoke against the R18-family site consent. Since the
/// `add-narou-novel-reader` change introducing a dedicated `SiteId.narou18`
/// has NOT yet merged, we route the revoke through the existing
/// `Site.noc` (ノクターン系) row — the same R18 surface — leaving the
/// future change free to add a finer-grained key.
class R18Section extends ConsumerStatefulWidget {
  const R18Section({super.key});

  @override
  ConsumerState<R18Section> createState() => _R18SectionState();
}

class _R18SectionState extends ConsumerState<R18Section> {
  Future<bool>? _granted;

  @override
  void initState() {
    super.initState();
    _granted = _load();
  }

  Future<bool> _load() async {
    return ref.read(consentRepositoryProvider).hasFreshConsent(Site.noc);
  }

  void _refresh() => setState(() => _granted = _load());

  Future<void> _reset() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        key: const Key('r18-reset-confirm'),
        title: const Text('年齢確認をやり直しますか?'),
        content: const Text('次回 R18 サイトを開く際に確認画面が表示されます。'),
        actions: <Widget>[
          TextButton(
            key: const Key('r18-reset-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('r18-reset-confirm-button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('リセットする'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(consentRepositoryProvider).revoke(Site.noc);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      id: 'r18',
      title: 'R18',
      children: <Widget>[
        FutureBuilder<bool>(
          future: _granted,
          builder: (BuildContext ctx, AsyncSnapshot<bool> snap) {
            final String label = snap.hasData
                ? (snap.data! ? '同意済み' : '未同意')
                : '...';
            return ListTile(
              key: const Key('r18-status'),
              title: const Text('年齢確認の状態'),
              trailing: Text(label),
            );
          },
        ),
        ListTile(
          key: const Key('r18-reset'),
          title: const Text('年齢確認をやり直す'),
          trailing: const Icon(Icons.restart_alt),
          onTap: _reset,
        ),
      ],
    );
  }
}
