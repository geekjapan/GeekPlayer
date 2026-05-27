import 'package:flutter/material.dart';

import '../../novel_kakuyomu/presentation/kakuyomu_settings_section.dart';
import 'settings_section.dart';

/// Standalone screen hosting [NovelSettingsSection].
///
/// This is the v0.1 "minimal route from home to settings" — the full
/// `add-app-settings` change replaces it with a unified Settings
/// screen that hosts sections from multiple features. Until then,
/// this screen ships as part of the novel-library change so the
/// consent toggles are reachable.
class NovelSettingsScreen extends StatelessWidget {
  const NovelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('オンライン小説 設定')),
      body: const SingleChildScrollView(
        child: Column(
          children: <Widget>[
            NovelSettingsSection(),
            KakuyomuSettingsSection(),
          ],
        ),
      ),
    );
  }
}
