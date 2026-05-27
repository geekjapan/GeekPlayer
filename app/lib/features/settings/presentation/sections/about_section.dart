import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../about/presentation/about_screen.dart';
import '../../../about/presentation/license_detail_screen.dart';
import '../../../about/presentation/license_screen.dart';
import '../settings_screen.dart';

/// About section — version row (live from `package_info_plus`) plus
/// navigation tiles to the About screen, the bundled license text, and
/// the OSS licenses list.
///
/// `add-about-and-licenses` replaced the original placeholders with the
/// real destinations.
class AboutSection extends ConsumerStatefulWidget {
  const AboutSection({super.key});

  @override
  ConsumerState<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<AboutSection> {
  Future<PackageInfo>? _info;

  @override
  void initState() {
    super.initState();
    _info = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      id: 'about',
      title: 'About',
      children: <Widget>[
        FutureBuilder<PackageInfo>(
          future: _info,
          builder: (BuildContext ctx, AsyncSnapshot<PackageInfo> snap) {
            return ListTile(
              key: const Key('about-version'),
              title: const Text('バージョン'),
              trailing: Text(
                snap.hasData
                    ? '${snap.data!.version}+${snap.data!.buildNumber}'
                    : '…',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            );
          },
        ),
        ListTile(
          key: const Key('about-license'),
          title: const Text('ライセンス'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const LicenseDetailScreen(
                title: 'GeekPlayer — ライセンス全文',
                assetPath: 'assets/legal/LICENSE',
              ),
            ),
          ),
        ),
        ListTile(
          key: const Key('about-oss-notices'),
          title: const Text('OSS Notices'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const LicenseListScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
