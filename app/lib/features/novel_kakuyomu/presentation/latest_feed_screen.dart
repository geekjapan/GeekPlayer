import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/utils/novel_date_formatter.dart';
import '../data/kakuyomu_providers.dart';
import '../domain/kakuyomu_feed_item.dart';
import 'work_detail_screen.dart';

/// Kakuyomu 新着 RSS feed list.
class KakuyomuLatestFeedScreen extends ConsumerStatefulWidget {
  const KakuyomuLatestFeedScreen({super.key});

  @override
  ConsumerState<KakuyomuLatestFeedScreen> createState() =>
      _KakuyomuLatestFeedScreenState();
}

class _KakuyomuLatestFeedScreenState
    extends ConsumerState<KakuyomuLatestFeedScreen> {
  Future<List<KakuyomuFeedItem>>? _pending;
  Future<List<KakuyomuFeedItem>>? _inflight;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    // Coalesce rapid refreshes (spec: "Rapid refreshes are coalesced").
    if (_inflight != null) {
      await _inflight;
      return;
    }
    final Future<List<KakuyomuFeedItem>> next = ref
        .read(kakuyomuNovelRepositoryProvider.future)
        .then((dynamic repo) {
          if (repo == null) {
            return <KakuyomuFeedItem>[];
          }
          // ignore: avoid_dynamic_calls
          return repo.latest() as Future<List<KakuyomuFeedItem>>;
        });
    setState(() {
      _pending = next;
      _inflight = next;
    });
    try {
      await next;
    } finally {
      if (mounted) {
        setState(() => _inflight = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カクヨム 新着')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<KakuyomuFeedItem>>(
          future: _pending,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<KakuyomuFeedItem>> snap,
              ) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ListView(
                    children: <Widget>[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('エラー: ${snap.error}'),
                        ),
                      ),
                    ],
                  );
                }
                final List<KakuyomuFeedItem> items = snap.data!;
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    final KakuyomuFeedItem it = items[i];
                    return ListTile(
                      title: Text(it.title),
                      subtitle: Text(
                        [
                          if (it.author != null && it.author!.isNotEmpty)
                            it.author,
                          if (it.publishedAt != null)
                            formatNovelDate(it.publishedAt, context),
                        ].whereType<String>().join(' · '),
                      ),
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
        ),
      ),
    );
  }
}
