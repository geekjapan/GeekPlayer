import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/narou_providers.dart';
import '../data/narou_ranking_repository.dart';
import '../domain/narou_ranking_type.dart';
import 'work_detail_screen.dart';

/// 6 タブ (日間 / 週間 / 月間 / 四半期 / 年間 / 累計) のランキング画面。
///
/// 仕様 `narou-novel-reader-ui` "Ranking screen with type selector":
///   - 各タブ切り替えで NarouRankingRepository を再呼び出し
///   - 上位 100 件を rank + title + author + pt で表示
///   - 行タップで [NarouWorkDetailScreen] を push
class NarouRankingScreen extends ConsumerStatefulWidget {
  const NarouRankingScreen({super.key});

  @override
  ConsumerState<NarouRankingScreen> createState() =>
      _NarouRankingScreenState();
}

class _NarouRankingScreenState extends ConsumerState<NarouRankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: NarouRankingType.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('なろうランキング'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: <Widget>[
            for (final NarouRankingType t in NarouRankingType.values)
              Tab(text: t.label),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: <Widget>[
          for (final NarouRankingType t in NarouRankingType.values)
            _RankingList(type: t),
        ],
      ),
    );
  }
}

class _RankingList extends ConsumerWidget {
  const _RankingList({required this.type});

  final NarouRankingType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<RankedWork>>(
      future: _load(ref),
      builder: (BuildContext context, AsyncSnapshot<List<RankedWork>> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('読み込みに失敗しました: ${snap.error}'));
        }
        final List<RankedWork> works = snap.data ?? <RankedWork>[];
        if (works.isEmpty) {
          return const Center(child: Text('ランキングデータがありません'));
        }
        return ListView.builder(
          key: ValueKey<String>('ranking-list-${type.name}'),
          itemCount: works.length,
          itemBuilder: (BuildContext context, int idx) {
            final RankedWork rw = works[idx];
            return ListTile(
              leading: CircleAvatar(child: Text(rw.rank.toString())),
              title: Text(rw.summary.title),
              subtitle: Text('${rw.summary.writer} • ${rw.pt} pt'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        NarouWorkDetailScreen(summary: rw.summary),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<RankedWork>> _load(WidgetRef ref) async {
    final NarouRankingRepository repo = await ref.read(
      narouRankingRepositoryProvider.future,
    );
    return repo.fetchRanking(type, DateTime.now());
  }
}
