import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../novel/presentation/novel_settings_screen.dart';
import 'kakuyomu_consent_dialog.dart';

/// Shown when the user reaches a Kakuyomu screen via a deep link (or
/// stale Navigator stack) but consent has not been granted / has been
/// revoked. Spec scenario "Decline hides Kakuyomu UI":
///
///   > entering it via deep link shows a disabled-state message
///   > linking to settings
class KakuyomuConsentRequiredScreen extends ConsumerWidget {
  const KakuyomuConsentRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('カクヨム')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            const Text(
              'カクヨムへの同意が必要です。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('kakuyomu-consent-required-show'),
              onPressed: () => KakuyomuConsentDialog.show(context),
              child: const Text('同意ダイアログを表示'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('kakuyomu-consent-required-open-settings'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NovelSettingsScreen(),
                ),
              ),
              child: const Text('設定を開く'),
            ),
          ],
        ),
      ),
    );
  }
}
