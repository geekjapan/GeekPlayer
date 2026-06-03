import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/policy_version.dart';
import '../../../l10n/app_localizations.dart';
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
  static Future<void> show(BuildContext context, {bool policyUpdated = false}) {
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // Block back-button dismiss to honour "dismissible only via
    // explicit action" (spec scenario "First launch shows the dialog").
    return PopScope<Object?>(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.consentDialogTitle),
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
                    l10n.consentPolicyUpdatedBanner,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              Text(l10n.consentDialogBody),
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
                      : (bool? v) => setState(() => _checked[s] = v ?? false),
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
            child: Text(l10n.consentDenyAll),
          ),
          FilledButton(
            key: const Key('consent-confirm'),
            onPressed: _saving ? null : _confirm,
            child: Text(l10n.consentConfirm),
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
