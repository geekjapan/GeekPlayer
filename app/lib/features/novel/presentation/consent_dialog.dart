import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/policy_version.dart';
import '../data/consent_repository.dart';

/// Modal first-launch consent dialog.
///
/// Spec `site-consent` "First-launch consent dialog":
///   - one checkbox per supported [Site]
///   - confirmable in any state (including all-denied via "すべて拒否")
///   - dismissible only via an explicit action (no barrier dismiss /
///     no back-button close in this dialog).
///
/// The dialog persists three rows to `site_consents` on confirmation,
/// stamped with [kPolicyVersion]. Callers should pop their navigator
/// after `await showDialog<bool>(...)` resolves.
class ConsentDialog extends ConsumerStatefulWidget {
  const ConsentDialog({super.key, this.policyUpdated = false});

  /// When true, render the "ポリシーが更新されました" banner used by the
  /// stale-policy re-prompt flow.
  final bool policyUpdated;

  /// Show the dialog modally above [context]. Returns the resolved
  /// future once the user confirms (no barrier-dismiss path exists).
  static Future<void> show(BuildContext context, {
    bool policyUpdated = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConsentDialog(policyUpdated: policyUpdated),
    );
  }

  @override
  ConsumerState<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends ConsumerState<ConsentDialog> {
  final Map<Site, bool> _checked = <Site, bool>{
    for (final Site s in Site.values) s: false,
  };
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Block back-button dismiss to honour "dismissible only via
    // explicit action" (spec scenario "First launch shows the dialog").
    return PopScope<Object?>(
      canPop: false,
      child: AlertDialog(
        title: const Text('オンライン小説サイトへの同意'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.policyUpdated)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ポリシーが更新されました',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              const Text(
                '本アプリは以下のサイトと通信して小説を取得します。'
                'ADR-0001 / ADR-0003 に従い、能動キャッシュ (利用者が'
                '「ライブラリに追加」を選択した作品のみ) を行い、各サイトの'
                'レート制限 (カクヨムは 1 req / 2 s) と robots.txt を尊重'
                'します。\n\n'
                'カクヨム本文は HTML をパースして取得します。サイト構造'
                'の変更で取得が失敗することがあります。',
              ),
              const SizedBox(height: 12),
              for (final Site s in Site.values)
                CheckboxListTile(
                  key: ValueKey<String>('consent-${s.code}'),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(s.displayName),
                  subtitle: Text(s.baseUrl.host),
                  value: _checked[s] ?? false,
                  onChanged: _saving
                      ? null
                      : (bool? v) =>
                          setState(() => _checked[s] = v ?? false),
                ),
              const SizedBox(height: 4),
              Text(
                'policyVersion: $kPolicyVersion',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('consent-deny-all'),
            onPressed: _saving ? null : _denyAll,
            child: const Text('すべて拒否'),
          ),
          FilledButton(
            key: const Key('consent-confirm'),
            onPressed: _saving ? null : _confirm,
            child: const Text('決定'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    await repo.saveDecisions(_checked);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _denyAll() async {
    setState(() => _saving = true);
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    await repo.saveDecisions(<Site, bool>{
      for (final Site s in Site.values) s: false,
    });
    if (mounted) Navigator.of(context).pop();
  }
}
