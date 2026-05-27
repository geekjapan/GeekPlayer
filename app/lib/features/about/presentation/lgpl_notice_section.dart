import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
                Text('LGPL-2.1+ 通知 (libmpv)', style: t.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            const SelectableText(
              'GeekPlayer は動画再生エンジンとして libmpv を採用しており、'
              'media_kit を介して 動的リンク で利用しています。'
              'libmpv は LGPL-2.1+ で配布されています。',
            ),
            const SizedBox(height: 8),
            const SelectableText(
              '利用者は LGPL-2.1+ の規定により、'
              'libmpv 部分のみを独立に修正・再構築 し、'
              'GeekPlayer 本体を再ビルドせずに 差し替える権利 を持ちます。'
              '差し替えた libmpv は LGPL の条件下で再配布できます。',
            ),
            const SizedBox(height: 12),
            Text('差し替え手順 (概要)', style: t.titleSmall),
            const SizedBox(height: 4),
            const SelectableText(
              '・macOS: アプリバンドル内 Contents/Frameworks/ 配下の '
              'Mpv.framework / libmpv.dylib を差し替え\n'
              '・Windows: GeekPlayer.exe と同じディレクトリの '
              'mpv-2.dll を差し替え\n'
              '・Android: APK 内 lib/<abi>/libmpv.so を差し替えた上で '
              'APK を再署名',
            ),
            const SizedBox(height: 8),
            _InlineLink(
              key: const Key('lgpl-upstream-link'),
              label: '上流ソース (mpv-player/mpv)',
              icon: Icons.open_in_new,
              onTap: () => _launch(context, _upstreamUrl),
            ),
            _InlineLink(
              key: const Key('lgpl-third-party-link'),
              label: '詳細は THIRD_PARTY_NOTICES を参照',
              icon: Icons.open_in_new,
              onTap: () => _launch(context, _thirdPartyNoticesUrl),
            ),
            _InlineLink(
              key: const Key('lgpl-full-text-link'),
              label: 'LGPL-2.1 全文',
              icon: Icons.chevron_right,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LicenseDetailScreen(
                      title: 'LGPL-2.1 全文',
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
    final Uri uri = Uri.parse(url);
    try {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクを開けませんでした')),
        );
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクを開けませんでした')),
        );
      }
    }
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: accent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
