import 'dart:async';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/interceptors/backoff_interceptor.dart';
import '../../../core/network/rate_limiter.dart';
import '../../../core/novel/models/site.dart';
import '../../novel/data/consent_repository.dart';
import 'narou_api_client.dart';
import 'narou_episode_fetcher.dart';
import 'narou_novel_repository.dart';
import 'narou_r18_novel_repository.dart';
import 'narou_ranking_repository.dart';

part 'narou_providers.g.dart';

/// `*.syosetu.com` 共通の RateLimiter。
///
/// ADR-0003 §取得方針-3: 1 req/sec, 並列 1〜2。API と本文 HTML は別 origin
/// だが、サーバ側からは同じ syosetu インフラに見えるため **同一バケット**
/// を共有する。
@Riverpod(keepAlive: true)
RateLimiter narouRateLimiter(Ref ref) {
  // 一般 + R18 が同じバケット、burst=2 で短期スパイクを少しだけ吸収。
  return RateLimiter(rate: 1.0, burst: 2, maxConcurrency: 2);
}

/// `package_info_plus` から取得したアプリバージョン文字列。
/// テストでは override される。
@Riverpod(keepAlive: true)
Future<String> narouAppVersion(Ref ref) async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return info.version.isEmpty ? '0.0.0' : info.version;
  } catch (_) {
    return '0.0.0';
  }
}

/// 共有 Dio を生成するヘルパ（インターセプタ全部入り）。
Dio _buildNarouDio() {
  final Dio dio = Dio();
  dio.interceptors.add(BackoffInterceptor());
  return dio;
}

/// 一般用 `NarouApiClient`（`api.syosetu.com/novelapi/api/`）。
@Riverpod(keepAlive: true)
Future<NarouApiClient> narouGeneralApiClient(Ref ref) async {
  final RateLimiter limiter = ref.watch(narouRateLimiterProvider);
  final String version = await ref.watch(narouAppVersionProvider.future);
  return NarouApiClient(
    baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
    dio: _buildNarouDio(),
    limiter: limiter,
    site: Site.narou,
    appVersion: version,
  );
}

/// R18 用 `NarouApiClient`（`api.syosetu.com/novel18api/api/`）。
@Riverpod(keepAlive: true)
Future<NarouApiClient> narouR18ApiClient(Ref ref) async {
  final RateLimiter limiter = ref.watch(narouRateLimiterProvider);
  final String version = await ref.watch(narouAppVersionProvider.future);
  return NarouApiClient(
    baseUrl: Uri.parse('https://api.syosetu.com/novel18api/api/'),
    dio: _buildNarouDio(),
    limiter: limiter,
    site: Site.noc,
    appVersion: version,
  );
}

/// 本文ページ取得用 fetcher (一般)。
@Riverpod(keepAlive: true)
Future<NarouEpisodeFetcher> narouGeneralEpisodeFetcher(Ref ref) async {
  final RateLimiter limiter = ref.watch(narouRateLimiterProvider);
  final String version = await ref.watch(narouAppVersionProvider.future);
  return NarouEpisodeFetcher(
    dio: _buildNarouDio(),
    limiter: limiter,
    bodyBaseUrl: Uri.parse('https://ncode.syosetu.com'),
    appVersion: version,
  );
}

/// 本文ページ取得用 fetcher (R18)。
@Riverpod(keepAlive: true)
Future<NarouEpisodeFetcher> narouR18EpisodeFetcher(Ref ref) async {
  final RateLimiter limiter = ref.watch(narouRateLimiterProvider);
  final String version = await ref.watch(narouAppVersionProvider.future);
  return NarouEpisodeFetcher(
    dio: _buildNarouDio(),
    limiter: limiter,
    bodyBaseUrl: Uri.parse('https://novel18.syosetu.com'),
    appVersion: version,
  );
}

/// 一般用リポジトリ。
@Riverpod(keepAlive: true)
Future<NarouNovelRepository> narouNovelRepository(Ref ref) async {
  final NarouApiClient client = await ref.watch(
    narouGeneralApiClientProvider.future,
  );
  final NarouEpisodeFetcher fetcher = await ref.watch(
    narouGeneralEpisodeFetcherProvider.future,
  );
  return NarouNovelRepository(apiClient: client, episodeFetcher: fetcher);
}

/// R18 用リポジトリ。
///
/// `Site.noc` の同意がない状態で watch すると `Future` が `StateError` で
/// reject される。Riverpod の `.future` を読む側は AsyncError を経由して
/// UI に「同意が必要」状態を伝える設計。
@Riverpod(keepAlive: true)
Future<NarouR18NovelRepository> narouR18NovelRepository(Ref ref) async {
  final NarouApiClient client = await ref.watch(
    narouR18ApiClientProvider.future,
  );
  final NarouEpisodeFetcher fetcher = await ref.watch(
    narouR18EpisodeFetcherProvider.future,
  );
  final ConsentRepository consent = ref.watch(consentRepositoryProvider);
  // 同意の有無を継続購読する Stream。`reverifyConsent` で都度 DB を見る。
  final StreamController<bool> controller = StreamController<bool>.broadcast();
  ref.listen(consentForNarou18Provider, (bool? prev, bool next) {
    if (!controller.isClosed) controller.add(next);
  });
  ref.onDispose(controller.close);
  final NarouR18NovelRepository repo = await NarouR18NovelRepository.create(
    apiClient: client,
    episodeFetcher: fetcher,
    consentRepository: consent,
    consentStream: controller.stream,
  );
  ref.onDispose(repo.dispose);
  return repo;
}

/// R18 (`Site.noc`) の同意状態を `bool` で返す Riverpod state。
///
/// UI は `ref.watch(consentForNarou18Provider)` だけ見ればよく、ダイアログ
/// の grant / revoke は内部で `notifier.refresh()` を呼ぶ。
@Riverpod(keepAlive: true)
class ConsentForNarou18 extends _$ConsentForNarou18 {
  @override
  bool build() {
    // ベースは false。`refresh()` で DB を読み直す。
    Future<void>.microtask(refresh);
    return false;
  }

  /// 強制再読み込み。
  Future<void> refresh() async {
    final ConsentRepository repo = ref.read(consentRepositoryProvider);
    state = await repo.hasFreshConsent(Site.noc);
  }
}

/// ランキングリポジトリ（一般のみ。R18 ランキング API は v0.1 では未対応）。
@Riverpod(keepAlive: true)
Future<NarouRankingRepository> narouRankingRepository(Ref ref) async {
  final NarouApiClient client = await ref.watch(
    narouGeneralApiClientProvider.future,
  );
  return NarouRankingRepository(apiClient: client);
}
