import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../data/narou_api_client.dart';
import '../data/narou_novel_repository.dart';
import '../data/narou_providers.dart';
import '../domain/narou_genre.dart';
import '../domain/narou_work_query.dart';
import '../domain/narou_work_summary.dart';
import 'work_detail_screen.dart';

/// なろう一般 / R18 共通の検索 UI。`site` で接続先を切り替える。
///
/// 仕様 `narou-novel-reader-ui` "Search screen with narou-specific
/// filters":
///   - キーワード入力 + ジャンル multi-select + 文字数 / 完結 / ピックアップ
///   - 結果は 20 件ずつ infinite-scroll
///   - フィルタ chip 表示 / X タップで除去 → 再検索
///   - 空結果は placeholder「該当する作品が見つかりませんでした」
class NarouSearchScreen extends ConsumerStatefulWidget {
  const NarouSearchScreen({super.key, this.site = Site.narou});

  final Site site;

  @override
  ConsumerState<NarouSearchScreen> createState() => _NarouSearchScreenState();
}

class _NarouSearchScreenState extends ConsumerState<NarouSearchScreen> {
  final TextEditingController _keyword = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Set<NarouGenre> _genres = <NarouGenre>{};
  int? _minChars;
  int? _maxChars;
  bool _completed = false;
  bool _pickup = false;

  bool _loading = false;
  bool _done = false;
  int _offset = 0;
  static const int _pageSize = 20;
  final List<NarouWorkSummary> _results = <NarouWorkSummary>[];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _keyword.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 200 &&
        !_loading &&
        !_done) {
      _fetch();
    }
  }

  NarouSearchOptions get _opts => NarouSearchOptions(
        site: widget.site,
        keyword: _keyword.text.isEmpty ? null : _keyword.text,
        limit: _pageSize,
        offset: _offset,
        genres: _genres,
        minChars: _minChars,
        maxChars: _maxChars,
        completed: _completed,
        pickup: _pickup,
      );

  Future<void> _runNewSearch() async {
    setState(() {
      _results.clear();
      _offset = 0;
      _done = false;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final NarouNovelRepository repo = await ref.read(
        narouNovelRepositoryProvider.future,
      );
      final NarouSearchResponse res = await repo.searchSummaries(_opts);
      setState(() {
        _results.addAll(res.works);
        _offset += res.works.length;
        if (res.works.length < _pageSize) _done = true;
      });
    } catch (_) {
      // エラーは error boundary 側で拾う想定。ローカルにはスナックバー。
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('検索に失敗しました。時間を置いて再試行してください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _removeFilter(VoidCallback action) {
    setState(action);
    _runNewSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site == Site.noc ? 'ノクターン検索' : 'なろう検索'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: const Key('narou-search-keyword'),
              controller: _keyword,
              decoration: const InputDecoration(
                labelText: 'キーワード',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _runNewSearch(),
            ),
          ),
          _GenrePicker(
            selected: _genres,
            onChanged: (Set<NarouGenre> next) {
              setState(() {
                _genres
                  ..clear()
                  ..addAll(next);
              });
            },
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: CheckboxListTile(
                  key: const Key('narou-completed'),
                  title: const Text('完結のみ'),
                  value: _completed,
                  onChanged: (bool? v) {
                    setState(() => _completed = v ?? false);
                  },
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  key: const Key('narou-pickup'),
                  title: const Text('ピックアップ'),
                  value: _pickup,
                  onChanged: (bool? v) {
                    setState(() => _pickup = v ?? false);
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              key: const Key('narou-search-submit'),
              onPressed: _runNewSearch,
              icon: const Icon(Icons.search),
              label: const Text('検索'),
            ),
          ),
          _ActiveFilterChips(
            keyword: _keyword.text,
            genres: _genres,
            completed: _completed,
            pickup: _pickup,
            onRemoveGenre: (NarouGenre g) =>
                _removeFilter(() => _genres.remove(g)),
            onClearCompleted: () => _removeFilter(() => _completed = false),
            onClearPickup: () => _removeFilter(() => _pickup = false),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const _EmptyPlaceholder()
                : ListView.builder(
                    controller: _scroll,
                    itemCount: _results.length + (_loading ? 1 : 0),
                    itemBuilder: (BuildContext context, int idx) {
                      if (idx >= _results.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final NarouWorkSummary s = _results[idx];
                      return ListTile(
                        key: ValueKey<String>('narou-result-${s.ncode}'),
                        title: Text(s.title),
                        subtitle: Text('${s.writer} / ${s.generalAllNo} 話'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  NarouWorkDetailScreen(summary: s),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          '該当する作品が見つかりませんでした',
          key: Key('narou-empty-placeholder'),
        ),
      ),
    );
  }
}

class _GenrePicker extends StatelessWidget {
  const _GenrePicker({required this.selected, required this.onChanged});

  final Set<NarouGenre> selected;
  final ValueChanged<Set<NarouGenre>> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          for (final NarouGenre g in NarouGenre.values)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                key: ValueKey<String>('narou-genre-${g.code}'),
                label: Text(g.label),
                selected: selected.contains(g),
                onSelected: (bool v) {
                  final Set<NarouGenre> next = Set<NarouGenre>.from(selected);
                  if (v) {
                    next.add(g);
                  } else {
                    next.remove(g);
                  }
                  onChanged(next);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.keyword,
    required this.genres,
    required this.completed,
    required this.pickup,
    required this.onRemoveGenre,
    required this.onClearCompleted,
    required this.onClearPickup,
  });

  final String keyword;
  final Set<NarouGenre> genres;
  final bool completed;
  final bool pickup;
  final ValueChanged<NarouGenre> onRemoveGenre;
  final VoidCallback onClearCompleted;
  final VoidCallback onClearPickup;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      if (keyword.isNotEmpty)
        InputChip(label: Text('"$keyword"'), onDeleted: null),
      for (final NarouGenre g in genres)
        InputChip(
          key: ValueKey<String>('active-filter-${g.code}'),
          label: Text(g.label),
          onDeleted: () => onRemoveGenre(g),
        ),
      if (completed)
        InputChip(
          key: const Key('active-filter-completed'),
          label: const Text('完結'),
          onDeleted: onClearCompleted,
        ),
      if (pickup)
        InputChip(
          key: const Key('active-filter-pickup'),
          label: const Text('ピックアップ'),
          onDeleted: onClearPickup,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }
}
