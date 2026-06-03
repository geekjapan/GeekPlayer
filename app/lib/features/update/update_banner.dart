/// `UpdateBanner` — shows a [MaterialBanner] when a newer GitHub release is
/// available. Checks on first build; silently hides itself on error or when
/// the app is already up to date.
///
/// Spec `auto-update` Requirement "App shows an update banner in the Settings
/// About section".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'update_checker.dart';
import 'update_checker_provider.dart';

/// Stateful widget that performs the update check on first build and surfaces
/// a dismissible banner when [UpdateAvailable] is returned.
///
/// Mount anywhere; it renders nothing when the app is up to date or when the
/// check fails.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  UpdateAvailable? _available;
  bool _dismissed = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final UpdateChecker checker = ref.read(updateCheckerProvider);
      final UpdateResult result = await checker.checkForUpdate(info.version);
      if (!mounted) return;
      if (result is UpdateAvailable) {
        setState(() => _available = result);
      }
    } on Object {
      // Silently suppress — spec: errors must NOT show a banner.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _available == null) return const SizedBox.shrink();

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final UpdateAvailable update = _available!;

    return MaterialBanner(
      key: const Key('update-banner'),
      content: Text(l10n.updateAvailableBannerBody(update.latestVersion)),
      leading: const Icon(Icons.system_update_alt),
      actions: <Widget>[
        TextButton(
          key: const Key('update-banner-download'),
          onPressed: () => _openRelease(context, update.releaseUrl),
          child: Text(l10n.updateAvailableDownload),
        ),
        TextButton(
          key: const Key('update-banner-dismiss'),
          onPressed: () => setState(() => _dismissed = true),
          child: Text(l10n.updateAvailableDismiss),
        ),
      ],
    );
  }

  Future<void> _openRelease(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.aboutLinkOpenError),
          ),
        );
      }
    }
  }
}
