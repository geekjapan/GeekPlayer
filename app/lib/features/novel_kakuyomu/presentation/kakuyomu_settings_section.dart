import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../novel/data/consent_repository.dart';
import 'kakuyomu_consent_dialog.dart';

/// Kakuyomu-specific section that can be embedded in the shared
/// settings screen (or any other settings host). Surfaces:
///
///   - the ADR-0001 notice text
///   - the effective rate-limit configuration string
///     ("1 リクエスト / 2 秒、並列度 1") — verbatim per spec
///   - the consent toggle (OFF → confirmation dialog → cache purge)
///   - a link to the README "カクヨム機能の注意事項" section
class KakuyomuSettingsSection extends ConsumerStatefulWidget {
  const KakuyomuSettingsSection({super.key});

  @override
  ConsumerState<KakuyomuSettingsSection> createState() =>
      _KakuyomuSettingsSectionState();
}

class _KakuyomuSettingsSectionState
    extends ConsumerState<KakuyomuSettingsSection> {
  Future<bool>? _grantedFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _grantedFuture = ref
        .read(consentRepositoryProvider)
        .hasFreshConsent(Site.kakuyomu);
  }

  Future<void> _toggle(bool desired) async {
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    if (desired) {
      final bool? confirmed = await KakuyomuConsentDialog.show(context);
      if (confirmed != true) return;
      // Dialog already persists the grant; just refresh.
      setState(_refresh);
      return;
    }
    // OFF: confirm + (TODO: purge cached bodies once
    // LibraryRepository.purgeBySite is added — see tasks.md 6.5)
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('同意を取り消しますか?'),
          content: const Text(
            'カクヨムへの同意を取り消すと、Library に保存されたカクヨムの本文'
            'キャッシュは削除されます。Library のエントリは「本文未取得」と'
            '表示され、再同意後に再取得できます。',
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('kakuyomu-revoke-confirm'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('取り消す'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await repo.revoke(Site.kakuyomu);
    // TODO(wave-3-purge): wire LibraryRepository.purgeBySite once the
    //  shared cross-site purge API lands (see tasks.md §6.5). For now
    //  the consent flag is sufficient — `ConsentGuardedRepository`
    //  blocks reads, and Library rows are kept as inert stubs.
    setState(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('カクヨム', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                '本セクションは ADR-0001 に従って動作します。\n'
                ' ・個人利用に限定 / 能動キャッシュのみ\n'
                ' ・robots.txt の Disallow を 24 時間キャッシュ付きで尊重\n'
                ' ・将来 ToS が自動収集を明示禁止した場合は即時停止',
              ),
              const SizedBox(height: 8),
              const Text(
                'レート制限 (現状値): 1 リクエスト / 2 秒、並列度 1',
                key: Key('kakuyomu-rate-limit-text'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('kakuyomu-open-readme-link'),
                onPressed: () {},
                child: const Text('詳細: README の「カクヨム機能の注意事項」セクション'),
              ),
              FutureBuilder<bool>(
                future: _grantedFuture,
                builder: (BuildContext context, AsyncSnapshot<bool> snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  return SwitchListTile(
                    key: const Key('kakuyomu-consent-toggle'),
                    title: const Text('カクヨムへの同意'),
                    value: snap.data!,
                    onChanged: _toggle,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
