import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../novel/data/consent_repository.dart';

/// Kakuyomu-specific consent dialog.
///
/// Surfaced from (1) the home Kakuyomu section's first tap and (2) the
/// settings screen's OFF→ON toggle. The text mirrors the ADR-0001
/// notice across the four canonical locations (README §カクヨム機能の
/// 注意事項 / `KakuyomuHtmlSource` docstring / `NovelSettingsSection`
/// permanent disclosure / this dialog).
///
/// Dark-pattern guard: both buttons use `OutlinedButton` /
/// `FilledButton` with the same default-sized text. The "同意しない"
/// button MUST NOT be visually smaller / dimmer than 「同意する」.
class KakuyomuConsentDialog extends ConsumerStatefulWidget {
  const KakuyomuConsentDialog({super.key});

  /// Show the dialog modally. Returns `true` when the user tapped
  /// 「同意する」, `false` when they tapped 「同意しない」, and `null` when
  /// dismissed (barrier or back).
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const KakuyomuConsentDialog(),
    );
  }

  @override
  ConsumerState<KakuyomuConsentDialog> createState() =>
      _KakuyomuConsentDialogState();
}

class _KakuyomuConsentDialogState extends ConsumerState<KakuyomuConsentDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('カクヨムへの同意'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '本アプリは、利用者の同意のもとでカクヨム公式サイトと通信して'
              '小説情報および本文を取得します。下記の運用規範に沿って動作します:',
            ),
            const SizedBox(height: 8),
            const _Bullet(text: '個人利用に限定。大規模クロール / 受動的ミラーリングは行いません。'),
            const _Bullet(text: '能動キャッシュのみ。ユーザーが「Library に追加」した作品の本文だけを保存します。'),
            const _Bullet(text: 'カクヨムへのアクセスは 1 リクエスト / 2 秒、並列度 1 に制限されます。'),
            const _Bullet(text: 'robots.txt の Disallow を 24 時間キャッシュ付きで尊重します。'),
            const _Bullet(text: 'User-Agent に GeekPlayer のバージョンと連絡先 URL を明示します。'),
            const _Bullet(text: '429 / 503 を受けたら指数バックオフ (最大 5 分) で再試行し、6 回で諦めます。'),
            const SizedBox(height: 12),
            Text(
              '詳細は ADR-0001 / README のカクヨム機能の注意事項を参照してください。'
              '将来、カクヨム公式 ToS が自動収集を明示禁止した場合は、本機能を即座に'
              '停止する方針です。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        OutlinedButton(
          key: const Key('kakuyomu-consent-decline'),
          onPressed: _saving ? null : () => _resolve(false),
          child: const Text('同意しない'),
        ),
        FilledButton(
          key: const Key('kakuyomu-consent-accept'),
          onPressed: _saving ? null : () => _resolve(true),
          child: const Text('同意する'),
        ),
      ],
    );
  }

  Future<void> _resolve(bool granted) async {
    setState(() => _saving = true);
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    if (granted) {
      await repo.grant(Site.kakuyomu);
    } else {
      await repo.revoke(Site.kakuyomu);
    }
    if (mounted) Navigator.of(context).pop(granted);
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('・'),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
