import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../settings_screen.dart';

/// About section — version row (live from `package_info_plus`), license,
/// OSS notices. Both rows route to a placeholder until
/// `add-about-and-licenses` lands (spec Requirement "About section links
/// to placeholder destinations").
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
            );
          },
        ),
        ListTile(
          key: const Key('about-license'),
          title: const Text('ライセンス'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pushPlaceholder(context),
        ),
        ListTile(
          key: const Key('about-oss-notices'),
          title: const Text('OSS Notices'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pushPlaceholder(context),
        ),
      ],
    );
  }

  void _pushPlaceholder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('未実装 (add-about-and-licenses)')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('この画面は add-about-and-licenses change で実装されます。'),
            ),
          ),
        ),
      ),
    );
  }
}
