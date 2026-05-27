import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_info_provider.dart';
import '../data/build_info.dart';
import 'license_detail_screen.dart';
import 'license_screen.dart';

/// `AboutScreen` — application identity, links, and entry to the OSS
/// licenses screen.
///
/// Spec `about-screen`:
///   - Application identity (name / version / build number / commit SHA)
///   - Apache-2.0 NOTICE line
///   - GitHub / Roadmap / Full License external links via url_launcher
///   - Navigation entry to LicenseListScreen
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String _githubUrl = 'https://github.com/geekjapan/GeekPlayer';
  static const String _roadmapUrl =
      'https://github.com/geekjapan/GeekPlayer/blob/main/docs/roadmap.md';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PackageInfo> info = ref.watch(packageInfoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('アプリ情報')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          _Header(info: info),
          const _NoticeCard(),
          _LinksCard(
            onGithub: () => _launch(context, _githubUrl),
            onRoadmap: () => _launch(context, _roadmapUrl),
            onFullLicense: () => _openBundledLicense(context),
          ),
          _OssLicensesButton(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LicenseListScreen(),
                ),
              );
            },
          ),
        ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
      }
    }
  }

  static void _openBundledLicense(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LicenseDetailScreen(
          title: 'GeekPlayer — ライセンス全文',
          assetPath: 'assets/legal/LICENSE',
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.info});
  final AsyncValue<PackageInfo> info;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: info.when(
          loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, StackTrace st) =>
              _identity(t, name: 'GeekPlayer', version: '-', buildNumber: '-'),
          data: (PackageInfo p) => _identity(
            t,
            name: p.appName.isEmpty ? 'GeekPlayer' : p.appName,
            version: p.version.isEmpty ? '-' : p.version,
            buildNumber: p.buildNumber.isEmpty ? '-' : p.buildNumber,
          ),
        ),
      ),
    );
  }

  Widget _identity(
    TextTheme t, {
    required String name,
    required String version,
    required String buildNumber,
  }) {
    return Column(
      key: const Key('about-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(name, style: t.titleLarge),
        const SizedBox(height: 8),
        _MetaRow(label: 'バージョン', value: version),
        _MetaRow(label: 'ビルド番号', value: buildNumber),
        _MetaRow(label: 'コミット', value: formattedGitSha()),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextStyle? label2 = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: label2?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(child: SelectableText(value, style: label2)),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Apache-2.0 ライセンス'),
            SizedBox(height: 4),
            SelectableText('Copyright 2026 GeekPlayer Contributors'),
          ],
        ),
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard({
    required this.onGithub,
    required this.onRoadmap,
    required this.onFullLicense,
  });
  final VoidCallback onGithub;
  final VoidCallback onRoadmap;
  final VoidCallback onFullLicense;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: <Widget>[
          ListTile(
            key: const Key('about-link-github'),
            leading: const Icon(Icons.code),
            title: const Text('GitHub リポジトリ'),
            trailing: const Icon(Icons.open_in_new),
            onTap: onGithub,
          ),
          ListTile(
            key: const Key('about-link-roadmap'),
            leading: const Icon(Icons.map_outlined),
            title: const Text('ロードマップ'),
            trailing: const Icon(Icons.open_in_new),
            onTap: onRoadmap,
          ),
          ListTile(
            key: const Key('about-link-license'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('ライセンス全文'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onFullLicense,
          ),
        ],
      ),
    );
  }
}

class _OssLicensesButton extends StatelessWidget {
  const _OssLicensesButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        key: const Key('about-oss-licenses'),
        leading: const Icon(Icons.list_alt),
        title: const Text('OSS ライセンス'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
