import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../age_gate/presentation/age_gate_dialog.dart';
import '../data/narou_providers.dart';
import 'ranking_screen.dart';
import 'search_screen.dart';

/// `NovelHomeSection` 配下に折り込まれる「なろう」エントリポイント群。
///
/// ADR-0004 に従い HomeScreen 本体は触らず、NovelHomeSection 内のタブ
/// として組み込む。本ファイルは検索 / ランキング / ピックアップ + R18 タブ
/// (consent された場合のみ表示) を提供する。
///
/// 仕様 `narou-novel-reader-ui` "Narou home section on the home screen":
///   - 初期状態で R18 タブは **非表示**
///   - R18 タブをタップした瞬間 AgeGateDialog 表示
///   - 同意後は以降 R18 タブが見えるようになる (Riverpod state 経由)
class NarouHomeSection extends ConsumerWidget {
  const NarouHomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool r18Granted = ref.watch(consentForNarou18Provider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '小説家になろう',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _NarouShortcut(
                key: const Key('narou-shortcut-search'),
                icon: Icons.search,
                label: '検索',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NarouSearchScreen(site: Site.narou),
                    ),
                  );
                },
              ),
              _NarouShortcut(
                key: const Key('narou-shortcut-ranking'),
                icon: Icons.emoji_events,
                label: 'ランキング',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NarouRankingScreen(),
                    ),
                  );
                },
              ),
              _NarouShortcut(
                key: const Key('narou-shortcut-pickup'),
                icon: Icons.star,
                label: 'ピックアップ',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NarouSearchScreen(site: Site.narou),
                    ),
                  );
                },
              ),
              // R18 ボタンは "未同意でも見せる" が、タップしたら必ず
                  // showAgeGate を通す (仕様 "Granting R18 consent reveals the
                  // R18 tab" — entrypoint をタップした瞬間にダイアログ)。
              _NarouShortcut(
                key: const Key('narou-shortcut-r18'),
                icon: Icons.lock_outline,
                label: r18Granted ? 'ノクターン' : 'ノクターン (要確認)',
                onTap: () async {
                  final bool granted = await showAgeGate(context, ref);
                  if (!granted || !context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NarouSearchScreen(site: Site.noc),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NarouShortcut extends StatelessWidget {
  const _NarouShortcut({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
