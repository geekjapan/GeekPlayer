import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kakuyomu_providers.dart';
import '../data/kakuyomu_rss_source.dart';
import '../domain/kakuyomu_feed_item.dart';
import 'work_detail_screen.dart';

/// 日次 / 週次 / 月次 / 累計 ランキング。タブごとに in-memory キャッシュ。
class KakuyomuRankingScreen extends ConsumerStatefulWidget {
  const KakuyomuRankingScreen({super.key});

  @override
  ConsumerState<KakuyomuRankingScreen> createState() =>
      _KakuyomuRankingScreenState();
}

class _KakuyomuRankingScreenState extends ConsumerState<KakuyomuRankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<KakuyomuRankingPeriod, Future<List<KakuyomuFeedItem>>> _cache =
      <KakuyomuRankingPeriod, Future<List<KakuyomuFeedItem>>>{};

  static const List<KakuyomuRankingPeriod> _tabs = <KakuyomuRankingPeriod>[
    KakuyomuRankingPeriod.daily,
    KakuyomuRankingPeriod.weekly,
    KakuyomuRankingPeriod.monthly,
    KakuyomuRankingPeriod.cumulative,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<KakuyomuFeedItem>> _load(KakuyomuRankingPeriod period) {
    return _cache.putIfAbsent(period, () {
      return ref
          .read(kakuyomuNovelRepositoryProvider.future)
          .then((dynamic repo) {
        if (repo == null) return <KakuyomuFeedItem>[];
        // ignore: avoid_dynamic_calls
        return repo.ranking(period) as Future<List<KakuyomuFeedItem>>;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カクヨム ランキング'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: '日次'),
            Tab(text: '週次'),
            Tab(text: '月次'),
            Tab(text: '累計'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((KakuyomuRankingPeriod p) => _RankingList(future: _load(p)))
            .toList(growable: false),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({required this.future});
  final Future<List<KakuyomuFeedItem>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KakuyomuFeedItem>>(
      future: future,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<KakuyomuFeedItem>> snap,
      ) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('エラー: ${snap.error}'));
        }
        final List<KakuyomuFeedItem> items = snap.data!;
        if (items.isEmpty) {
          return const Center(child: Text('項目がありません'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int i) {
            final KakuyomuFeedItem it = items[i];
            return ListTile(
              leading: Text('${i + 1}'),
              title: Text(it.title),
              subtitle: Text(it.author ?? ''),
              onTap: it.workId.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              KakuyomuWorkDetailScreen(workId: it.workId),
                        ),
                      ),
            );
          },
        );
      },
    );
  }
}
