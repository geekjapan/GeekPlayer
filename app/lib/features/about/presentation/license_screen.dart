import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/oss_license_repository.dart';
import '../domain/license_entry.dart';
import 'license_detail_screen.dart';
import 'lgpl_notice_section.dart';

/// `LicenseListScreen` — top of the OSS licenses tree.
///
/// Layout (spec `oss-license-notices` + `lgpl-compliance` D7):
///   1. LGPL Notice Section (libmpv-only, top)
///   2. Apache-2.0 NOTICE section (GeekPlayer)
///   3. Dependency list (from OssLicenseRepository)
class LicenseListScreen extends ConsumerWidget {
  const LicenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OssLicenseRepository repo = ref.watch(ossLicenseRepositoryProvider);
    final List<LicenseEntry> entries = repo.fetchEntries();
    return Scaffold(
      appBar: AppBar(title: const Text('OSS ライセンス')),
      body: ListView.builder(
        key: const Key('license-list'),
        itemCount: entries.length + 2,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return const LgplNoticeSection();
          }
          if (index == 1) {
            return const _ApacheNoticeCard();
          }
          final LicenseEntry e = entries[index - 2];
          return ListTile(
            key: Key('license-entry-${e.name}'),
            title: Text(e.name),
            subtitle: e.version != null ? Text(e.version!) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LicenseDetailScreen.forEntry(e),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Apache-2.0 NOTICE card for GeekPlayer itself.
///
/// Spec `oss-license-notices` Requirement "Apache-2.0 NOTICE section for
/// GeekPlayer" — visible above the dependency list, contains the copyright
/// line and a tappable "ライセンス全文" link to the bundled LICENSE asset.
class _ApacheNoticeCard extends StatelessWidget {
  const _ApacheNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('apache-notice-section'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Apache-2.0 NOTICE', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const SelectableText('Copyright 2026 GeekPlayer Contributors'),
            const SizedBox(height: 4),
            const SelectableText(
              'GeekPlayer 本体は Apache License 2.0 で配布されています。',
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LicenseDetailScreen(
                      title: 'GeekPlayer — ライセンス全文',
                      assetPath: 'assets/legal/LICENSE',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ライセンス全文',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
