import '../../../core/novel/models/site.dart';
import '../domain/narou_ranking_type.dart';
import '../domain/narou_work_summary.dart';
import 'narou_api_client.dart';

/// `rankget` + `detail` を組み合わせて「ランキング上位 N 件」を返す
/// リポジトリ。
///
/// 2 段階呼び出し（design.md D6）:
///   1. `rankget(type, date)` で ncode + rank + pt のリストを取得
///   2. 上位 100 件の ncode を `detail()` に投げ、メタデータを batch 取得
///   3. ncode → 詳細のマッピングを作って rank 順に整列して返す
///
/// detail で取得できなかった ncode は `narou-novel-source` spec の
/// "Missing detail for a ranked ncode is tolerated" シナリオに従い、
/// **黙ってドロップ + 構造化ログ** 扱いとする（v0.1 では print に倒す）。
class NarouRankingRepository {
  NarouRankingRepository({required NarouApiClient apiClient})
    : _api = apiClient;

  final NarouApiClient _api;

  Site get site => _api.site;

  /// 指定タイプ + 日付のランキング上位 [limit] 件（最大 100）を返す。
  Future<List<RankedWork>> fetchRanking(
    NarouRankingType type,
    DateTime date, {
    int limit = 100,
  }) async {
    final List<NarouRankEntry> ranks = await _api.rankget(type, date);
    if (ranks.isEmpty) return const <RankedWork>[];
    final List<NarouRankEntry> top = ranks
        .take(limit > 100 ? 100 : limit)
        .toList(growable: false);
    final List<String> ncodes = top
        .map((NarouRankEntry e) => e.ncode)
        .toList(growable: false);
    final List<NarouWorkSummary> details = await _api.detail(ncodes);
    final Map<String, NarouWorkSummary> byNcode = <String, NarouWorkSummary>{
      for (final NarouWorkSummary s in details) s.ncode.toLowerCase(): s,
    };
    final List<RankedWork> out = <RankedWork>[];
    int dropped = 0;
    for (final NarouRankEntry r in top) {
      final NarouWorkSummary? detail = byNcode[r.ncode.toLowerCase()];
      if (detail == null) {
        dropped += 1;
        continue;
      }
      out.add(RankedWork(summary: detail, rank: r.rank, pt: r.pt));
    }
    if (dropped > 0) {
      // ignore: avoid_print
      print('[NarouRankingRepository] dropped $dropped entries without detail');
    }
    return out;
  }
}

/// ランキング 1 行分: メタデータ + rank + pt。
class RankedWork {
  const RankedWork({
    required this.summary,
    required this.rank,
    required this.pt,
  });

  final NarouWorkSummary summary;
  final int rank;
  final int pt;
}
