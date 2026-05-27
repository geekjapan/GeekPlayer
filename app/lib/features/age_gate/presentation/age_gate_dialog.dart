import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../novel/data/consent_repository.dart';
import '../../novel_narou/data/narou_providers.dart';

/// R18 系統 (ノクターン / ミッドナイト / ムーンライト) アクセス前の
/// 年齢確認モーダル。
///
/// 仕様 `r18-age-gate` "Age gate dialog before R18 functionality":
///   - barrier-dismissible は **false**。明示的「はい / いいえ」のみ
///   - 「はい」: `SiteConsentRepository.grant(Site.noc)` → ダイアログ閉じ
///   - 「いいえ」または system back: 同意を残さずキャンセル
///
/// `showAgeGate(context)` ヘルパで戻り値 (`true` = 同意済) を受け取る。
class AgeGateDialog extends ConsumerStatefulWidget {
  const AgeGateDialog({super.key});

  @override
  ConsumerState<AgeGateDialog> createState() => _AgeGateDialogState();
}

class _AgeGateDialogState extends ConsumerState<AgeGateDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PopScope<Object?>(
      canPop: false,
      child: AlertDialog(
        title: const Text('年齢確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'これより先はノクターン / ミッドナイト / ムーンライト系統 '
              '(成人向け作品) を含むエリアです。\n\n'
              'コンテンツの閲覧には 18 歳以上であることの確認が必要です。',
            ),
            const SizedBox(height: 12),
            Text(
              '※ 同意は「設定」→「オンライン小説」→「年齢確認をやり直す」'
              'からいつでも取り消せます。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('age-gate-no'),
            onPressed: _saving
                ? null
                : () => Navigator.of(context).pop<bool>(false),
            child: const Text('いいえ'),
          ),
          FilledButton(
            key: const Key('age-gate-yes'),
            onPressed: _saving ? null : _grantAndClose,
            child: const Text('はい、18歳以上です'),
          ),
        ],
      ),
    );
  }

  Future<void> _grantAndClose() async {
    setState(() => _saving = true);
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    await repo.grant(Site.noc);
    // 共有 state も更新
    // ignore: unused_result
    await ref.read(consentForNarou18Provider.notifier).refresh();
    if (!mounted) return;
    Navigator.of(context).pop<bool>(true);
  }
}

/// 年齢確認モーダルを開いて、`true` = 同意済 / `false` = 拒否 を返す。
///
/// 既に `Site.noc` で `hasFreshConsent` が true の場合は即座に `true` を返す
/// （仕様 "Subsequent access reuses the granted consent"）。
Future<bool> showAgeGate(BuildContext context, WidgetRef ref) async {
  final ConsentRepository repo = ref.read(consentRepositoryProvider);
  final bool already = await repo.hasFreshConsent(Site.noc);
  if (already) return true;
  if (!context.mounted) return false;
  final bool? res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AgeGateDialog(),
  );
  return res ?? false;
}
