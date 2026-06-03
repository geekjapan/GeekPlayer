/// `UpdateBanner` — shows a [MaterialBanner] when a newer GitHub release is
/// available. Checks on first build; silently hides itself on error or when
/// the app is already up to date.
///
/// When a compatible release asset is found for the running platform, tapping
/// "Download" fetches the asset with progress and then offers an install/open
/// button that hands the file to the OS. When no compatible asset is found the
/// original browser-launch fallback is used.
///
/// Spec `auto-update` Requirements: banner, download, install, fallback.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'release_asset.dart';
import 'update_checker.dart';
import 'update_checker_provider.dart';
import 'update_downloader.dart';
import 'update_installer.dart';

// ---------------------------------------------------------------------------
// State machine
// ---------------------------------------------------------------------------

enum _DownloadState { idle, downloading, readyToInstall }

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

  _DownloadState _downloadState = _DownloadState.idle;
  double _progress = 0;
  String? _downloadedPath;

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
      content: _buildContent(l10n, update),
      leading: const Icon(Icons.system_update_alt),
      actions: _buildActions(context, l10n, update),
    );
  }

  Widget _buildContent(AppLocalizations l10n, UpdateAvailable update) {
    if (_downloadState == _DownloadState.downloading) {
      final int percent = (_progress * 100).round().clamp(0, 100);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.updateDownloading(percent)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            key: const Key('update-progress'),
            value: _progress <= 0 ? null : _progress,
          ),
        ],
      );
    }
    return Text(l10n.updateAvailableBannerBody(update.latestVersion));
  }

  List<Widget> _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    UpdateAvailable update,
  ) {
    if (_downloadState == _DownloadState.readyToInstall) {
      return <Widget>[
        TextButton(
          key: const Key('update-banner-install'),
          onPressed: () => _install(context),
          child: Text(l10n.updateInstall),
        ),
        TextButton(
          key: const Key('update-banner-dismiss'),
          onPressed: () => setState(() => _dismissed = true),
          child: Text(l10n.updateAvailableDismiss),
        ),
      ];
    }

    return <Widget>[
      TextButton(
        key: const Key('update-banner-download'),
        onPressed: _downloadState == _DownloadState.idle
            ? () => _startDownload(context, update)
            : null,
        child: Text(l10n.updateAvailableDownload),
      ),
      TextButton(
        key: const Key('update-banner-dismiss'),
        onPressed: () => setState(() => _dismissed = true),
        child: Text(l10n.updateAvailableDismiss),
      ),
    ];
  }

  Future<void> _startDownload(
    BuildContext context,
    UpdateAvailable update,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // Select asset for current platform.
    final ReleaseAsset? asset = selectAssetForPlatform(
      update.assets,
      Theme.of(context).platform,
    );

    if (asset == null) {
      // No compatible asset — fall back to browser.
      final bool hadAssets = update.assets.isNotEmpty;
      if (hadAssets && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.updateNoCompatibleAsset)));
      }
      await _openRelease(context, update.releaseUrl);
      return;
    }

    setState(() {
      _downloadState = _DownloadState.downloading;
      _progress = 0;
    });

    try {
      final UpdateDownloader downloader = ref.read(updateDownloaderProvider);
      final String path = await downloader.download(
        asset,
        onProgress: (int received, int total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadedPath = path;
        _downloadState = _DownloadState.readyToInstall;
      });
    } on DioException catch (e) {
      if (!context.mounted) return;
      setState(() => _downloadState = _DownloadState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.updateDownloadFailed}: ${e.message ?? e.type.name}',
          ),
        ),
      );
    } on Object {
      if (!context.mounted) return;
      setState(() => _downloadState = _DownloadState.idle);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.updateDownloadFailed)));
    }
  }

  Future<void> _install(BuildContext context) async {
    final String? path = _downloadedPath;
    if (path == null) return;
    try {
      final UpdateInstaller installer = ref.read(updateInstallerProvider);
      await installer.openForInstall(path);
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
