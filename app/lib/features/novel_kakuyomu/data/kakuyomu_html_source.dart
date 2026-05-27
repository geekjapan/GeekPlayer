import 'package:dio/dio.dart';

import '../../../core/network/errors.dart';
import '../domain/exceptions.dart';
import '../domain/kakuyomu_episode.dart';
import '../domain/kakuyomu_work.dart';
import 'kakuyomu_html_parser.dart';

/// カクヨム作品ページ / エピソードページの HTML をフェッチし、
/// [KakuyomuHtmlParser] に渡して構造化データに変換するソース。
///
/// **本ソースは [ADR-0001](../../../../../docs/adr/0001-online-novel-fetch-policy.md)
/// の運用規範に従って動作します**:
///
/// - **個人利用** に限定（受動的クロール / 大規模ミラーリングを行わない）
/// - **能動キャッシュ** のみ（ユーザーが Library に追加した作品本文のみ永続化、
///   閲覧のみのアクセスは DB に書き込まない）
/// - **1 リクエスト / 2 秒**、並列度 1 の `RateLimiter` を Dio Interceptor で
///   全リクエストに適用
/// - **robots.txt** を 24 時間キャッシュして disallow パスへのアクセスを
///   事前拒否（`RobotsDisallowedException`）
/// - **429** / **503** で指数バックオフ（初期 1 秒 → ×2、上限 5 分、`Retry-After`
///   優先、最大 6 リトライ）、6 回失敗で
///   [KakuyomuUpstreamUnavailableException] に変換して UI に伝える
/// - カクヨム公式 ToS が将来「自動収集を明示禁止」を加えた場合は
///   `feature_flags.dart` の `kakuyomuEnabled = false` で完全停止し、
///   キャッシュ済み本文を削除する（[ADR-0001] §Consequences）
///
/// HTML パース失敗時は [KakuyomuParseException] を投げ、UI 側は
/// `parser_failure_fallback.dart` の fallback panel（公式ビューアを
/// 外部ブラウザで開く）で読書継続を保証する。
class KakuyomuHtmlSource {
  KakuyomuHtmlSource({required Dio dio, KakuyomuHtmlParser? parser})
      : _dio = dio, // ignore: prefer_initializing_formals
        _parser = parser ?? const KakuyomuHtmlParser();

  final Dio _dio;
  final KakuyomuHtmlParser _parser;

  static const String _baseHost = 'https://kakuyomu.jp';

  /// Fetch and parse a work-detail page.
  Future<KakuyomuWorkDetail> fetchWork(String workId,
      {CancelToken? cancelToken}) async {
    final String url = '$_baseHost/works/$workId';
    final String body = await _get(url, cancelToken: cancelToken);
    try {
      return _parser.parseWorkPage(body, workId: workId);
    } on KakuyomuParseException {
      rethrow;
    } catch (e) {
      throw KakuyomuParseException(
        message: 'parseWorkPage raised: $e',
        selector: '<work-root>',
        url: url,
      );
    }
  }

  /// Fetch and parse an episode body.
  ///
  /// Maps HTTP 404 to [KakuyomuEpisodeNotFoundException] and parse
  /// failures to [KakuyomuParseException].
  Future<KakuyomuEpisodeBody> fetchEpisodeBody(
    String workId,
    String episodeId, {
    CancelToken? cancelToken,
  }) async {
    final String url = '$_baseHost/works/$workId/episodes/$episodeId';
    final String body = await _get(
      url,
      cancelToken: cancelToken,
      onNotFound: () => KakuyomuEpisodeNotFoundException(
        workId: workId,
        episodeId: episodeId,
      ),
    );
    try {
      return _parser.parseEpisodePage(
        body,
        workId: workId,
        episodeId: episodeId,
      );
    } on KakuyomuParseException {
      rethrow;
    } catch (e) {
      throw KakuyomuParseException(
        message: 'parseEpisodePage raised: $e',
        selector: '<episode-root>',
        url: url,
      );
    }
  }

  Future<String> _get(
    String url, {
    CancelToken? cancelToken,
    Object Function()? onNotFound,
  }) async {
    try {
      final Response<String> resp = await _dio.get<String>(
        url,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.plain),
      );
      final String? body = resp.data;
      if (body == null || body.isEmpty) {
        throw KakuyomuParseException(
          message: 'empty body',
          selector: '<root>',
          url: url,
        );
      }
      return body;
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 404 && onNotFound != null) {
        throw onNotFound();
      }
      // Retries exhausted (BackoffInterceptor converts to RateLimitExceededError)
      if (e.error is RateLimitExceededError) {
        throw KakuyomuUpstreamUnavailableException(
          message: (e.error as RateLimitExceededError).message,
          lastStatus: status,
        );
      }
      // Robots disallow
      if (e.error is RobotsDisallowedError) {
        rethrow;
      }
      throw KakuyomuUpstreamUnavailableException(
        message: 'http error for $url: ${e.message ?? e.type.name}',
        lastStatus: status,
      );
    }
  }
}
