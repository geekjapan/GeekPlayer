import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kakuyomu_providers.dart';
import '../domain/exceptions.dart';
import '../domain/kakuyomu_episode.dart';
import '../domain/reader_segment.dart';
import 'parser_failure_fallback.dart';

/// Episode body reader.
///
/// Renders the parsed [KakuyomuEpisodeBody] as paragraphs with inline
/// `<ruby>` rendered via [Text.rich]. Provides "前のエピソード" /
/// "次のエピソード" navigation by walking the [episodeIds] list passed
/// in by `KakuyomuWorkDetailScreen`.
///
/// NB: [ResumePoint] (bookmarks) persistence is the responsibility of
/// the shared `NovelPageSession`; this screen does not write its own
/// scroll position to the DB. (Wave 2 wired `novel_bookmarks`.)
class KakuyomuReaderScreen extends ConsumerStatefulWidget {
  const KakuyomuReaderScreen({
    super.key,
    required this.workId,
    required this.episodeIds,
    required this.initialIndex,
  });

  final String workId;
  final List<String> episodeIds;
  final int initialIndex;

  @override
  ConsumerState<KakuyomuReaderScreen> createState() =>
      _KakuyomuReaderScreenState();
}

class _KakuyomuReaderScreenState extends ConsumerState<KakuyomuReaderScreen> {
  late int _index;
  Future<KakuyomuEpisodeBody>? _pending;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _load();
  }

  void _load() {
    final String epId = widget.episodeIds[_index];
    setState(() {
      _pending = ref
          .read(kakuyomuNovelRepositoryProvider.future)
          .then((dynamic repo) {
        if (repo == null) {
          throw StateError('Kakuyomu disabled');
        }
        // ignore: avoid_dynamic_calls
        return repo.fetchEpisodeFullBody(widget.workId, epId)
            as Future<KakuyomuEpisodeBody>;
      });
    });
  }

  void _move(int delta) {
    final int next = _index + delta;
    if (next < 0 || next >= widget.episodeIds.length) return;
    setState(() => _index = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('カクヨム エピソード ${_index + 1} / ${widget.episodeIds.length}'),
      ),
      body: FutureBuilder<KakuyomuEpisodeBody>(
        future: _pending,
        builder: (
          BuildContext context,
          AsyncSnapshot<KakuyomuEpisodeBody> snap,
        ) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final Object err = snap.error!;
            if (err is KakuyomuParseException) {
              return ParserFailureFallback(
                error: err,
                url:
                    'https://kakuyomu.jp/works/${widget.workId}/episodes/${widget.episodeIds[_index]}',
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('エラー: $err'),
            );
          }
          final KakuyomuEpisodeBody body = snap.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  body.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                for (final ReaderSegment s in body.paragraphs)
                  _SegmentView(segment: s),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    TextButton(
                      key: const Key('kakuyomu-prev-episode'),
                      onPressed: _index > 0 ? () => _move(-1) : null,
                      child: const Text('前のエピソード'),
                    ),
                    TextButton(
                      key: const Key('kakuyomu-next-episode'),
                      onPressed: _index < widget.episodeIds.length - 1
                          ? () => _move(1)
                          : null,
                      child: const Text('次のエピソード'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SegmentView extends StatelessWidget {
  const _SegmentView({required this.segment});
  final ReaderSegment segment;

  @override
  Widget build(BuildContext context) {
    return switch (segment) {
      ParagraphSegment(:final String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(text),
        ),
      BlankLineSegment() => const SizedBox(height: 12),
      RubyParagraphSegment(:final List<RubyRun> runs) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                for (final RubyRun r in runs)
                  switch (r) {
                    TextRun(:final String text) => TextSpan(text: text),
                    // Compact ruby: render base + bracketed reading.
                    // A richer vertical ruby layout is left to a future
                    // change once the shared reader UI lands.
                    RubyPair(:final String base, :final String reading) =>
                      TextSpan(text: '$base($reading)'),
                  },
              ],
            ),
          ),
        ),
    };
  }
}
