import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/novel/fake_novel_repository.dart';
import '../../../core/novel/models/episode.dart';
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../../../core/novel/models/work_id.dart';
import '../domain/add_to_library_use_case.dart';
import '../domain/remove_from_library_use_case.dart';

/// Developer-only menu to inject / remove a synthetic `Work` so we can
/// exercise the Library flow end-to-end on macOS / Windows / Android
/// before site-specific changes land (tasks.md 9.7).
///
/// Mounted only when `kDebugMode` is true via the (future) Settings →
/// Developer screen. Not wired into release UI.
class NovelDebugMenu extends ConsumerWidget {
  const NovelDebugMenu({super.key});

  static const WorkId _fixtureId =
      WorkId(site: Site.narou, externalId: 'debug-1');

  FakeNovelRepository _seed() {
    final DateTime now = DateTime.utc(2026, 5, 27);
    return FakeNovelRepository(
      site: Site.narou,
      seed: <WorkId, FakeWorkData>{
        _fixtureId: FakeWorkData(
          work: Work(
            id: _fixtureId,
            title: 'デバッグ用ダミー作品',
            author: 'GeekPlayer',
            synopsis: '能動キャッシュ動作確認用の固定作品。',
            episodeCount: 3,
            addedAt: now,
          ),
          episodes: <Episode>[
            Episode(id: EpisodeId(1), title: '第1話'),
            Episode(id: EpisodeId(2), title: '第2話'),
            Episode(id: EpisodeId(3), title: '第3話'),
          ],
          bodies: <int, EpisodeBody>{
            1: EpisodeBody(body: '第1話の本文', fetchedAt: now),
            2: EpisodeBody(body: '第2話の本文', fetchedAt: now),
            3: EpisodeBody(body: '第3話の本文', fetchedAt: now),
          },
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AddToLibraryUseCase add = ref.watch(addToLibraryUseCaseProvider);
    final RemoveFromLibraryUseCase rm =
        ref.watch(removeFromLibraryUseCaseProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Novel Debug Menu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'FakeNovelRepository を使ってダミー Work を Library に投入 / '
            '削除します (能動キャッシュ動作確認用)。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              FilledButton(
                key: const Key('debug-add-dummy'),
                onPressed: () async {
                  await add.call(_seed(), _fixtureId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ダミー Work を追加しました'),
                      ),
                    );
                  }
                },
                child: const Text('ダミー Work を追加'),
              ),
              OutlinedButton(
                key: const Key('debug-remove-dummy'),
                onPressed: () async {
                  await rm.call(_fixtureId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ダミー Work を削除しました'),
                      ),
                    );
                  }
                },
                child: const Text('ダミー Work を削除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
