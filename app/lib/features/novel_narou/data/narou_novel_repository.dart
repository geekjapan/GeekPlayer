import 'dart:async';

import '../../../core/novel/models/episode.dart';
import '../../../core/novel/models/site.dart';
import '../../../core/novel/models/work.dart';
import '../../../core/novel/models/work_id.dart';
import '../../../core/novel/models/work_query.dart';
import '../../../core/novel/novel_repository.dart';
import '../domain/narou_episode.dart';
import '../domain/narou_work_query.dart';
import '../domain/narou_work_summary.dart';
import 'narou_api_client.dart';
import 'narou_episode_fetcher.dart';

/// 一般「小説家になろう」向けの [NovelRepository] 実装。
///
/// 一般サイトには年齢確認の同意要件がないため、コンストラクタは特別な
/// gating を行わない（R18 版は別クラス [NarouR18NovelRepository]）。
class NarouNovelRepository implements NovelRepository {
  NarouNovelRepository({
    required NarouApiClient apiClient,
    required NarouEpisodeFetcher episodeFetcher,
  }) : _api = apiClient,
       _fetcher = episodeFetcher;

  final NarouApiClient _api;
  final NarouEpisodeFetcher _fetcher;

  @override
  Site get site => Site.narou;

  @override
  Future<List<Work>> searchWorks(WorkQuery query) async {
    final NarouSearchOptions opts = query is NarouSearchOptions
        ? query
        : NarouSearchOptions(
            site: site,
            keyword: query.keyword,
            limit: query.limit,
            offset: query.offset,
          );
    final NarouSearchResponse res = await _api.search(opts);
    return res.works.map((NarouWorkSummary s) => s.toWork()).toList();
  }

  /// 検索 API 互換: NarouSearchOptions そのまま渡せる版（UI 用）。
  Future<NarouSearchResponse> searchSummaries(NarouSearchOptions opts) {
    return _api.search(opts);
  }

  @override
  Future<Work> fetchWork(WorkId id) async {
    if (id.site != site) {
      throw ArgumentError(
        'NarouNovelRepository.fetchWork: site mismatch ${id.site.code}',
      );
    }
    final List<NarouWorkSummary> details = await _api.detail(<String>[
      id.externalId,
    ]);
    if (details.isEmpty) {
      throw NarouResponseError('no detail for ${id.externalId}');
    }
    return details.first.toWork();
  }

  @override
  Stream<Episode> fetchEpisodes(WorkId workId) async* {
    // まず詳細を取って `general_all_no` を確認し、1..N をストリーミング。
    // タイトルは "第N話" を仮置きする（実 HTML 取得時に置き換える設計だが、
    // v0.1 ではメタデータ単体での詳細話タイトル取得 API がないため、
    // 短編は単一話、連載は番号のみで進める）。
    final Work w = await fetchWork(workId);
    for (int i = 1; i <= w.episodeCount; i++) {
      yield Episode(id: EpisodeId(i), title: '第$i話');
    }
  }

  @override
  Future<EpisodeBody> fetchEpisodeBody(
    WorkId workId,
    EpisodeId episodeId,
  ) async {
    final String body = await _fetcher.fetchBody(
      workId.externalId,
      episodeId.index,
    );
    return EpisodeBody(body: body, fetchedAt: DateTime.now().toUtc());
  }
}
