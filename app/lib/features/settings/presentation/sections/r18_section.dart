import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/novel/models/site.dart';
import '../../../../l10n/app_localizations.dart';
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

  void _refresh() {
    final Future<bool> next = _load();
    setState(() {
      _granted = next;
    });
  }

  Future<void> _reset() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        key: const Key('r18-reset-confirm'),
        title: Text(l10n.settingsR18ResetConfirmTitle),
        content: Text(l10n.settingsR18ResetConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('r18-reset-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('r18-reset-confirm-button'),
            style: destructiveFilledButtonStyle(ctx),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionReset),
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return SettingsSection(
      id: 'r18',
      title: l10n.settingsSectionR18,
      children: <Widget>[
        FutureBuilder<bool>(
          future: _granted,
          builder: (BuildContext ctx, AsyncSnapshot<bool> snap) {
            final String label = snap.hasData
                ? (snap.data!
                      ? l10n.settingsR18StatusGranted
                      : l10n.settingsR18StatusDenied)
                : '...';
            return ListTile(
              key: const Key('r18-status'),
              title: Text(l10n.settingsR18Status),
              trailing: Text(label),
            );
          },
        ),
        ListTile(
          key: const Key('r18-reset'),
          title: Text(l10n.settingsR18Reset),
          trailing: Icon(
            Icons.restart_alt,
            color: Theme.of(context).colorScheme.error,
          ),
          onTap: _reset,
        ),
      ],
    );
  }
}
