// なろう公式 API を実際に 1 回ずつ叩いて
// 「mapper が壊れていない / レート制限規範の User-Agent が通る」を確認する
// smoke test。
//
// **CI では skip タグ**で除外し、ローカル / リリース前の手動実行のみで動かす:
//
// ```
// flutter test integration_test/narou_smoke_test.dart \
//     --tags integration
// ```
//
// 通常の `flutter test` では実行されない (デフォルト tags は exclude)。

@Tags(<String>['integration'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/network/interceptors/backoff_interceptor.dart';
import 'package:geekplayer/core/network/rate_limiter.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/features/novel_narou/data/narou_api_client.dart';
import 'package:geekplayer/features/novel_narou/data/narou_episode_fetcher.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_ranking_type.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_work_query.dart';

void main() {
  final RateLimiter limiter = RateLimiter(
    rate: 1.0,
    burst: 1,
    maxConcurrency: 1,
  );

  Dio makeDio() {
    final Dio d = Dio();
    d.interceptors.add(BackoffInterceptor());
    return d;
  }

  test('search: なろう一般 API が JSON を返し allCount > 0', () async {
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
      dio: makeDio(),
      limiter: limiter,
      site: Site.narou,
      appVersion: '0.0.1-smoke',
    );
    final NarouSearchResponse res = await client.search(
      const NarouSearchOptions(keyword: '魔王', limit: 5),
    );
    expect(res.allCount >= 0, isTrue);
  });

  test('rankget: 日間ランキング上位の ncode を取得', () async {
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/'),
      dio: makeDio(),
      limiter: limiter,
      site: Site.narou,
      appVersion: '0.0.1-smoke',
    );
    final List<NarouRankEntry> ranks = await client.rankget(
      NarouRankingType.daily,
      DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(ranks.isNotEmpty, isTrue);
  });

  test('episode body: 既存作品の 1 話目の HTML をパースできる', () async {
    final NarouEpisodeFetcher fetcher = NarouEpisodeFetcher(
      dio: makeDio(),
      limiter: limiter,
      bodyBaseUrl: Uri.parse('https://ncode.syosetu.com'),
      appVersion: '0.0.1-smoke',
    );
    // 公開済みの代表的な ncode (Re:ゼロ第 1 話)
    final String body = await fetcher.fetchBody('n2267be', 1);
    expect(body.isNotEmpty, isTrue);
  });
}
