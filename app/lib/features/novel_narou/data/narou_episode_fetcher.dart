import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import '../../../core/network/rate_limiter.dart';
import '../../../core/network/user_agent.dart';

/// なろう / ノクターン系の **本文ページ HTML** 取得 + パーサ。
///
/// ADR-0003 で確定:
///   - 一般: `https://ncode.syosetu.com/<ncode>/<n>/`
///   - R18:  `https://novel18.syosetu.com/<ncode>/<n>/`
///   - レートリミッタは `*.syosetu.com` 共通バケットを **API クライアントと
///     同じインスタンス**で利用する（origin 単位 1 req/sec, 並列 1）。
///
/// 短編 / 連載の差は呼び出し側が決めることもできるが、本実装では
/// **URL 形式が `<ncode>/<n>/` で統一されている**ため `episodeIndex`
/// を素直に埋めれば短編 (n=1) も連載も同じ経路で取得できる。
///
/// 本クラスは HTML を取得して **本文プレーンテキスト** に変換するだけで、
/// ルビ記法 `|漢字《かんじ》` などの "後段パース" は
/// [NarouRubyParser] が担当する責務分担。
class NarouEpisodeFetcher {
  NarouEpisodeFetcher({
    required Dio dio,
    required RateLimiter limiter,
    required Uri bodyBaseUrl,
    required String appVersion,
    // ignore: prefer_initializing_formals
  }) : _dio = dio,
       // ignore: prefer_initializing_formals
       _limiter = limiter,
       // ignore: prefer_initializing_formals
       _bodyBaseUrl = bodyBaseUrl {
    _dio.options = _dio.options.copyWith(
      headers: <String, dynamic>{
        ..._dio.options.headers,
        kUserAgentHeader: buildUserAgent(appVersion),
      },
      connectTimeout:
          _dio.options.connectTimeout ?? const Duration(seconds: 15),
      receiveTimeout:
          _dio.options.receiveTimeout ?? const Duration(seconds: 30),
    );
  }

  final Dio _dio;
  final RateLimiter _limiter;
  final Uri _bodyBaseUrl;

  /// `<ncode>/<episodeIndex>/` のページを取って、本文プレーンテキストを返す。
  ///
  /// 短編 (`novel_type=2`) は `episodeIndex=1` を指定して呼ぶ。
  /// 連載の各話も同じ URL 形式で取得できる。
  Future<String> fetchBody(String ncode, int episodeIndex) {
    return _limiter.run<String>(() async {
      final String lower = ncode.toLowerCase();
      final Uri url = _bodyBaseUrl.replace(path: '/$lower/$episodeIndex/');
      final Response<String> res = await _dio.getUri<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final String html = res.data ?? '';
      return _extractBody(html);
    });
  }

  /// `<div id="novel_honbun">` の中の `<p>` を改行で連結する。
  /// なろうの本文 DOM 構造に依存する。失敗時は空文字を返す（呼び出し側
  /// で構造変更の検知ログを残す）。
  static String _extractBody(String html) {
    final dom.Document doc = html_parser.parse(html);
    final dom.Element? honbun = doc.getElementById('novel_honbun');
    if (honbun == null) {
      // 新 DOM (2023 以降の novelview) では `.p-novel__body` 等にスイッチ
      // した報告がある。fallback として代表的なクラスを順に試す。
      final List<String> fallbacks = <String>['.p-novel__body', '.novel_view'];
      for (final String sel in fallbacks) {
        final dom.Element? alt = doc.querySelector(sel);
        if (alt != null) {
          return _joinParagraphs(alt);
        }
      }
      return '';
    }
    return _joinParagraphs(honbun);
  }

  static String _joinParagraphs(dom.Element root) {
    final List<dom.Element> ps = root.querySelectorAll('p');
    if (ps.isEmpty) return root.text.trim();
    return ps.map((dom.Element p) => p.text).join('\n').trim();
  }
}
