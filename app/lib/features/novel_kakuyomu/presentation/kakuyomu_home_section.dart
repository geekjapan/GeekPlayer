import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/novel/models/site.dart';
import '../../novel/data/consent_repository.dart';
import 'kakuyomu_consent_dialog.dart';
import 'latest_feed_screen.dart';
import 'ranking_screen.dart';
import 'search_screen.dart';

/// Home-screen entry card for the Kakuyomu feature.
///
/// Lives under the existing `NovelHomeSection` (per ADR-0004 / mission
/// brief — HomeScreen is never edited directly). Hidden when
/// `kakuyomuEnabled` is `false` OR the user has not granted consent.
///
/// Tapping a chip routes to the matching Kakuyomu screen. The first
/// time the user taps any chip without prior consent, the
/// [KakuyomuConsentDialog] is shown — only if they tap 「同意する」 does
/// the navigation proceed.
class KakuyomuSection extends ConsumerWidget {
  const KakuyomuSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kakuyomuEnabled) return const SizedBox.shrink();
    final AsyncValue<bool> granted = ref.watch(_kakuyomuGrantedProvider);
    return granted.when(
      loading: () => const SizedBox.shrink(),
      error: (Object _, StackTrace _) => const SizedBox.shrink(),
      data: (bool isGranted) {
        if (!isGranted) {
          // Hidden when consent is revoked (spec scenario
          // "Decline hides Kakuyomu UI").
          return _ConsentInvite(onTap: () => _maybeShowDialog(context, ref));
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('カクヨム', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _Chip(
                        keyId: 'kakuyomu-tab-search',
                        label: '検索',
                        onPressed: () => _open(
                          context,
                          ref,
                          (_) => const KakuyomuSearchScreen(),
                        ),
                      ),
                      _Chip(
                        keyId: 'kakuyomu-tab-latest',
                        label: '新着',
                        onPressed: () => _open(
                          context,
                          ref,
                          (_) => const KakuyomuLatestFeedScreen(),
                        ),
                      ),
                      _Chip(
                        keyId: 'kakuyomu-tab-ranking',
                        label: 'ランキング',
                        onPressed: () => _open(
                          context,
                          ref,
                          (_) => const KakuyomuRankingScreen(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    WidgetBuilder builder,
  ) async {
    final bool granted = await ref
        .read(consentRepositoryProvider)
        .hasFreshConsent(Site.kakuyomu);
    if (!granted) {
      if (!context.mounted) return;
      final bool? ok = await KakuyomuConsentDialog.show(context);
      if (ok != true) return;
      ref.invalidate(_kakuyomuGrantedProvider);
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  Future<void> _maybeShowDialog(BuildContext context, WidgetRef ref) async {
    final bool? ok = await KakuyomuConsentDialog.show(context);
    if (ok == true) ref.invalidate(_kakuyomuGrantedProvider);
  }
}

class _ConsentInvite extends StatelessWidget {
  const _ConsentInvite({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: ListTile(
          key: const Key('kakuyomu-consent-invite'),
          title: const Text('カクヨムを利用するには同意が必要です'),
          subtitle: const Text('タップして詳細を確認 (ADR-0001)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.keyId,
    required this.label,
    required this.onPressed,
  });

  final String keyId;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: Key(keyId),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

final FutureProvider<bool> _kakuyomuGrantedProvider = FutureProvider<bool>((
  Ref ref,
) async {
  return ref.read(consentRepositoryProvider).hasFreshConsent(Site.kakuyomu);
});
