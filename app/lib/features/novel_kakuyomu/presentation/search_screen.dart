import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kakuyomu_providers.dart';
import '../domain/exceptions.dart';
import '../domain/kakuyomu_feed_item.dart';
import '../domain/kakuyomu_search_query.dart';
import 'work_detail_screen.dart';

/// Kakuyomu keyword search.
///
/// Spec `kakuyomu-novel-reader-ui / Search screen`: empty result →
/// "結果が見つかりませんでした"; network failure → 再試行 CTA.
class KakuyomuSearchScreen extends ConsumerStatefulWidget {
  const KakuyomuSearchScreen({super.key});

  @override
  ConsumerState<KakuyomuSearchScreen> createState() =>
      _KakuyomuSearchScreenState();
}

class _KakuyomuSearchScreenState extends ConsumerState<KakuyomuSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Future<List<KakuyomuFeedItem>>? _pending;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String kw = _controller.text.trim();
    if (kw.isEmpty) return;
    setState(() {
      _pending = ref.read(kakuyomuNovelRepositoryProvider.future).then((
        dynamic repo,
      ) {
        if (repo == null) {
          throw StateError('Kakuyomu is disabled (kakuyomuEnabled=false)');
        }
        // ignore: avoid_dynamic_calls
        return repo.search(KakuyomuSearchQuery(keyword: kw))
            as Future<List<KakuyomuFeedItem>>;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カクヨム検索')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('kakuyomu-search-input'),
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'キーワードで検索',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('kakuyomu-search-submit'),
                  onPressed: _submit,
                  child: const Text('検索'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _pending == null
                  ? const Center(child: Text('キーワードを入力して検索してください'))
                  : FutureBuilder<List<KakuyomuFeedItem>>(
                      future: _pending,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<KakuyomuFeedItem>> snap,
                          ) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snap.hasError) {
                              final Object err = snap.error!;
                              return _ErrorCard(err: err, onRetry: _submit);
                            }
                            final List<KakuyomuFeedItem> items = snap.data!;
                            if (items.isEmpty) {
                              return const Center(child: Text('結果が見つかりませんでした'));
                            }
                            return ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (BuildContext context, int i) {
                                final KakuyomuFeedItem it = items[i];
                                return ListTile(
                                  title: Text(it.title),
                                  subtitle: Text(it.author ?? ''),
                                  onTap: it.workId.isEmpty
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                KakuyomuWorkDetailScreen(
                                                  workId: it.workId,
                                                ),
                                          ),
                                        ),
                                );
                              },
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.err, required this.onRetry});
  final Object err;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String msg = err is KakuyomuUpstreamUnavailableException
        ? 'カクヨムが混雑しています。時間を置いて再試行してください。'
        : err is SiteConsentDeniedException
        ? 'カクヨムへの同意が必要です。設定画面から有効化してください。'
        : 'エラーが発生しました: $err';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(msg),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('kakuyomu-search-retry'),
              onPressed: onRetry,
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}
