import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../../l10n/app_localizations.dart';
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.kakuyomuConsentDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.kakuyomuConsentDialogIntro),
            const SizedBox(height: 8),
            _Bullet(text: l10n.kakuyomuConsentBullet1),
            _Bullet(text: l10n.kakuyomuConsentBullet2),
            _Bullet(text: l10n.kakuyomuConsentBullet3),
            _Bullet(text: l10n.kakuyomuConsentBullet4),
            _Bullet(text: l10n.kakuyomuConsentBullet5),
            _Bullet(text: l10n.kakuyomuConsentBullet6),
            const SizedBox(height: 12),
            Text(l10n.kakuyomuConsentFooter, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: <Widget>[
        OutlinedButton(
          key: const Key('kakuyomu-consent-decline'),
          onPressed: _saving ? null : () => _resolve(false),
          child: Text(l10n.kakuyomuConsentDecline),
        ),
        FilledButton(
          key: const Key('kakuyomu-consent-accept'),
          onPressed: _saving ? null : () => _resolve(true),
          child: Text(l10n.kakuyomuConsentAccept),
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
