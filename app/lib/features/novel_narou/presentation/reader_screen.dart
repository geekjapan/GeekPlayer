import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_session.dart';
import '../../../core/novel/models/episode.dart';
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/novel_repository.dart';
import '../../novel/data/library_repository.dart';
import '../data/narou_providers.dart';
import 'narou_ruby_parser.dart';
import 'reader_settings.dart';

/// 縦スクロール・本文読書画面。
///
/// 仕様 `narou-novel-reader-ui` "Reader screen with vertical scroll":
///   - `SingleChildScrollView` + `SelectableText.rich`
///   - フォントサイズ / 行間 / テーマを設定パネル (BottomSheet) で変更
///   - 前話 / 次話ボタン、最終話は次話を disable
///   - 栞復元: 末尾 5% は 0 リセット (本クラスで処理)、Library 経由 (DAO)
///     で `(workId, episodeIndex, scrollFraction)` を保存
class NarouReaderScreen extends ConsumerStatefulWidget {
  const NarouReaderScreen({
    super.key,
    required this.workId,
    required this.initialEpisode,
    required this.title,
    required this.totalEpisodes,
  });

  final WorkId workId;
  final EpisodeId initialEpisode;
  final String title;
  final int totalEpisodes;

  @override
  ConsumerState<NarouReaderScreen> createState() => _NarouReaderScreenState();
}

class _NarouReaderScreenState extends ConsumerState<NarouReaderScreen> {
  late EpisodeId _current;
  final ScrollController _scroll = ScrollController();
  Future<EpisodeBody>? _bodyFuture;
  double _restoreFraction = 0.0;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialEpisode;
    _loadEpisode();
  }

  @override
  void dispose() {
    _persistScroll();
    _scroll.dispose();
    super.dispose();
  }

  Future<NovelRepository> _repo() async {
    return widget.workId.site == Site.noc
        ? await ref.read(narouR18NovelRepositoryProvider.future)
        : await ref.read(narouNovelRepositoryProvider.future);
  }

  Future<void> _loadEpisode() async {
    final NovelRepository repo = await _repo();
    setState(() {
      _bodyFuture = repo.fetchEpisodeBody(widget.workId, _current);
      _restored = false;
    });
    // 栞があれば復元位置を覚える。
    final LibraryRepository lib = ref.read(libraryRepositoryProvider);
    final PagePosition? pos = await lib.getBookmark(widget.workId);
    if (pos != null && pos.pageIndex == _current.index) {
      _restoreFraction = pos.scrollFraction;
    } else {
      _restoreFraction = 0.0;
    }
  }

  Future<void> _persistScroll() async {
    if (!_scroll.hasClients) return;
    final double max = _scroll.position.maxScrollExtent;
    final double pos = _scroll.position.pixels;
    double fraction = max <= 0 ? 0.0 : (pos / max);
    if (fraction.isNaN || fraction.isInfinite) fraction = 0.0;
    fraction = fraction.clamp(0.0, 1.0);
    // 末尾 5% は 0 リセット (仕様 "Near-end resume restarts the episode")
    if (fraction >= 0.95) fraction = 0.0;
    final LibraryRepository lib = ref.read(libraryRepositoryProvider);
    await lib.saveBookmark(
      widget.workId,
      PagePosition(pageIndex: _current.index, scrollFraction: fraction),
    );
  }

  void _goPrev() async {
    if (_current.index <= 1) return;
    await _persistScroll();
    setState(() => _current = EpisodeId(_current.index - 1));
    _loadEpisode();
  }

  void _goNext() async {
    if (_current.index >= widget.totalEpisodes) return;
    await _persistScroll();
    setState(() => _current = EpisodeId(_current.index + 1));
    _loadEpisode();
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (BuildContext sheetContext) => const _ReaderSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReaderTheme theme = ref.watch(readerThemeProvider);
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: Text('${widget.title} - 第${_current.index}話'),
        actions: <Widget>[
          IconButton(
            key: const Key('reader-open-settings'),
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: FutureBuilder<EpisodeBody>(
        future: _bodyFuture,
        builder: (BuildContext context, AsyncSnapshot<EpisodeBody> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('読み込みに失敗しました: ${snap.error}'));
          }
          final String body = snap.data?.body ?? '';
          // 1 フレーム後にスクロール復元
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_restored && _scroll.hasClients && _restoreFraction > 0.0) {
              final double target =
                  _scroll.position.maxScrollExtent * _restoreFraction;
              _scroll.jumpTo(target);
              _restored = true;
            }
          });
          final NarouRubyParser parser = const NarouRubyParser();
          return SingleChildScrollView(
            key: ValueKey<int>(_current.index),
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            child: SelectableText.rich(
              TextSpan(
                children: parser.parse(
                  body,
                  baseStyle: TextStyle(
                    fontSize: theme.fontSize,
                    height: theme.lineHeight,
                    color: theme.foreground,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TextButton.icon(
              key: const Key('reader-prev'),
              onPressed: _current.index > 1 ? _goPrev : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('前話'),
            ),
            TextButton.icon(
              key: const Key('reader-next'),
              onPressed: _current.index < widget.totalEpisodes ? _goNext : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('次話'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReaderTheme theme = ref.watch(readerThemeProvider);
    final ReaderThemeNotifier notifier =
        ref.read(readerThemeProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('読書設定', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Text('文字サイズ'),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('reader-font-down'),
                  onPressed: () =>
                      notifier.setFontSize(theme.fontSize - 2),
                  icon: const Icon(Icons.text_decrease),
                ),
                Text('${theme.fontSize.toInt()} pt'),
                IconButton(
                  key: const Key('reader-font-up'),
                  onPressed: () =>
                      notifier.setFontSize(theme.fontSize + 2),
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const Text('行間'),
                Expanded(
                  child: Slider(
                    key: const Key('reader-lineheight-slider'),
                    min: 1.2,
                    max: 2.4,
                    divisions: 6,
                    value: theme.lineHeight,
                    label: theme.lineHeight.toStringAsFixed(1),
                    onChanged: (double v) => notifier.setLineHeight(v),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final ReaderColorScheme c in ReaderColorScheme.values)
                  ChoiceChip(
                    key: ValueKey<String>('reader-theme-${c.name}'),
                    label: Text(c.label),
                    selected: theme.colorScheme == c,
                    onSelected: (_) => notifier.setColorScheme(c),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
