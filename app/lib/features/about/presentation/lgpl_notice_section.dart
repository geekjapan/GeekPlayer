import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'license_detail_screen.dart';

/// LGPL notice section for libmpv. Rendered at the top of the
/// `LicenseListScreen`.
///
/// Spec `lgpl-compliance` — covers every Requirement in that capability:
///   - libmpv LGPL-2.1+ + dynamic linking statement
///   - Upstream source URL (mpv-player/mpv)
///   - Per-platform replacement instructions (macOS / Windows / Android)
///   - User rights statement
///   - Bundled LGPL-2.1 full license text link
class LgplNoticeSection extends StatelessWidget {
  const LgplNoticeSection({super.key});

  static const String _upstreamUrl = 'https://github.com/mpv-player/mpv';
  static const String _thirdPartyNoticesUrl =
      'https://github.com/geekjapan/GeekPlayer/blob/main/THIRD_PARTY_NOTICES.md';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextTheme t = Theme.of(context).textTheme;
    final Color accent = Theme.of(context).colorScheme.primary;
    return Card(
      key: const Key('lgpl-notice-section'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.gavel, color: accent),
                const SizedBox(width: 8),
                Text(l10n.lgplNoticeTitle, style: t.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(l10n.lgplNoticeBody),
            const SizedBox(height: 8),
            SelectableText(l10n.lgplNoticeRights),
            const SizedBox(height: 12),
            Text(l10n.lgplNoticeReplacementTitle, style: t.titleSmall),
            const SizedBox(height: 4),
            SelectableText(l10n.lgplNoticeReplacementBody),
            const SizedBox(height: 8),
            _InlineLink(
              buttonKey: const Key('lgpl-upstream-link'),
              label: l10n.lgplUpstreamLink,
              icon: Icons.open_in_new,
              onTap: () => _launch(context, _upstreamUrl),
            ),
            _InlineLink(
              buttonKey: const Key('lgpl-third-party-link'),
              label: l10n.lgplThirdPartyLink,
              icon: Icons.open_in_new,
              onTap: () => _launch(context, _thirdPartyNoticesUrl),
            ),
            _InlineLink(
              buttonKey: const Key('lgpl-full-text-link'),
              label: l10n.lgplFullTextLink,
              icon: Icons.chevron_right,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LicenseDetailScreen(
                      title: l10n.lgplLicenseScreenTitle,
                      assetPath: 'assets/legal/LGPL-2.1.txt',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _launch(BuildContext context, String url) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Uri uri = Uri.parse(url);
    try {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aboutLinkOpenError)));
      }
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

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final Key buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: buttonKey,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
