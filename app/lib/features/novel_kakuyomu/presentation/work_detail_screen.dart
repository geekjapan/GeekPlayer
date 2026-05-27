import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/novel_repository.dart';
import '../../novel/data/library_repository.dart';
import '../data/kakuyomu_novel_repository.dart';
import '../data/kakuyomu_providers.dart';
import '../domain/exceptions.dart';
import '../domain/kakuyomu_episode.dart';
import '../domain/kakuyomu_work.dart';
import 'parser_failure_fallback.dart';
import 'reader_screen.dart';

/// 作品詳細 + 「Library に追加」ボタン。
class KakuyomuWorkDetailScreen extends ConsumerStatefulWidget {
  const KakuyomuWorkDetailScreen({super.key, required this.workId});

  final String workId;

  @override
  ConsumerState<KakuyomuWorkDetailScreen> createState() =>
      _KakuyomuWorkDetailScreenState();
}

class _KakuyomuWorkDetailScreenState
    extends ConsumerState<KakuyomuWorkDetailScreen> {
  Future<KakuyomuWorkDetail>? _pending;
  CancelToken? _addToLibraryCancel;
  bool _adding = false;
  int _addProgress = 0;
  int _addTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _pending = ref
          .read(kakuyomuNovelRepositoryProvider.future)
          .then((dynamic repo) {
        if (repo == null) {
          throw StateError('Kakuyomu disabled');
        }
        // ignore: avoid_dynamic_calls
        return repo.fetchWorkDetail(widget.workId) as Future<KakuyomuWorkDetail>;
      });
    });
  }

  Future<void> _addToLibrary(KakuyomuWorkDetail detail) async {
    final KakuyomuNovelRepository? repo =
        await ref.read(kakuyomuNovelRepositoryProvider.future);
    if (repo == null) return;
    final NovelRepository asNovel = repo;
    final LibraryRepository library = ref.read(libraryRepositoryProvider);
    setState(() {
      _adding = true;
      _addProgress = 0;
      _addTotal = detail.episodes.length;
      _addToLibraryCancel = CancelToken();
    });
    try {
      await library.addToLibrary(
        asNovel,
        WorkId(site: Site.kakuyomu, externalId: widget.workId),
        onProgress: (int fetched, int total) {
          if (mounted) {
            setState(() {
              _addProgress = fetched;
              _addTotal = total;
            });
          }
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library に追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加に失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  void _cancelAdd() {
    _addToLibraryCancel?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カクヨム 作品詳細')),
      body: FutureBuilder<KakuyomuWorkDetail>(
        future: _pending,
        builder: (
          BuildContext context,
          AsyncSnapshot<KakuyomuWorkDetail> snap,
        ) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final Object err = snap.error!;
            if (err is KakuyomuParseException) {
              return ParserFailureFallback(
                error: err,
                url: 'https://kakuyomu.jp/works/${widget.workId}',
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('エラー: $err'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            );
          }
          final KakuyomuWorkDetail detail = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                detail.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(detail.author),
              const SizedBox(height: 8),
              if (detail.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: detail.tags
                      .map(
                        (String t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 12),
              Text(detail.synopsis),
              const SizedBox(height: 16),
              if (_adding)
                Column(
                  children: <Widget>[
                    LinearProgressIndicator(
                      value: _addTotal == 0 ? null : _addProgress / _addTotal,
                    ),
                    const SizedBox(height: 4),
                    Text('取得中… $_addProgress / $_addTotal'),
                    TextButton(
                      key: const Key('kakuyomu-add-cancel'),
                      onPressed: _cancelAdd,
                      child: const Text('キャンセル'),
                    ),
                  ],
                )
              else
                FilledButton(
                  key: const Key('kakuyomu-add-to-library'),
                  onPressed: () => _addToLibrary(detail),
                  child: const Text('Library に追加'),
                ),
              const SizedBox(height: 16),
              Text(
                'エピソード (${detail.episodes.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (int i = 0; i < detail.episodes.length; i++)
                ListTile(
                  key: ValueKey<String>(
                    'kakuyomu-episode-${detail.episodes[i].id}',
                  ),
                  leading: Text('${i + 1}'),
                  title: Text(detail.episodes[i].title),
                  subtitle: detail.episodes[i].publishedAt == null
                      ? null
                      : Text(
                          detail.episodes[i].publishedAt!
                              .toLocal()
                              .toIso8601String(),
                        ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => KakuyomuReaderScreen(
                        workId: widget.workId,
                        episodeIds: detail.episodes
                            .map((KakuyomuEpisodeSummary e) => e.id)
                            .toList(growable: false),
                        initialIndex: i,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
