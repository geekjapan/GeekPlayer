import 'package:dio/dio.dart';

import '../../../core/network/rate_limiter.dart';
import '../../../core/network/user_agent.dart';
import '../../../core/novel/models/site.dart';
import '../domain/narou_episode.dart';
import '../domain/narou_ranking_type.dart';
import '../domain/narou_work_detail.dart';
import '../domain/narou_work_query.dart';
import '../domain/narou_work_summary.dart';

/// 検索 API レスポンスの薄いラッパ。
///
/// なろう公式 API は **配列の先頭要素**に `{ "allcount": N }` を入れ、
/// 残りに各作品オブジェクトを並べる癖があるため、`allcount` と
/// `works` を別々のフィールドとして取り出す。
class NarouSearchResponse {
  const NarouSearchResponse({required this.allCount, required this.works});

  final int allCount;
  final List<NarouWorkSummary> works;
}

/// ランキング (`rankget`) の 1 件分。
class NarouRankEntry {
  const NarouRankEntry({
    required this.ncode,
    required this.rank,
    required this.pt,
  });

  final String ncode;
  final int rank;
  final int pt;
}

/// 公式 API (`api.syosetu.com`) への低レベル GET ラッパ。
///
/// design.md D1 / D2:
///   - 一般 (`novelapi`) と R18 (`novel18api`) は **base URL 差し替えのみ**
///     で同じインターフェース。
///   - `out=json` を全リクエストに自動付与。
///   - `User-Agent` は `package_info_plus` 由来の `appVersion` から
///     [buildUserAgent] で生成して全リクエスト固定（インターセプタで
///     都度上書きする経路は使わない — Dio の baseOptions.headers で固定）。
///   - レート制限 (`api.syosetu.com` バケット) は **呼び出し側で
///     [RateLimiter.run] にラップ**して適用する。Dio interceptor 経由でも
///     可能だが、本クラスではテスト容易性を優先して明示的にラップする。
///   - 429 / 503 は `dio` の `Interceptor` でリトライされる前提（本クラスは
///     リトライロジックを持たない、ADR-0003 §取得方針-6 参照）。
class NarouApiClient {
  NarouApiClient({
    required Uri baseUrl,
    required Dio dio,
    required RateLimiter limiter,
    required this.site,
    required String appVersion,
  }) : _dio = dio, // ignore: prefer_initializing_formals
       _limiter = limiter, // ignore: prefer_initializing_formals
       _baseUrl = baseUrl {
    // 既存 baseOptions を尊重しつつ baseUrl と User-Agent を上書き。
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl.toString(),
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
  final Uri _baseUrl;

  /// 紐づくサイト (`Site.narou` or `Site.noc`)。mapper に渡す。
  final Site site;

  /// 検索: `out=json` 固定、`offset` / `limit` は [opts.offset] / [opts.limit]。
  ///
  /// なろう API は `allcount` を先頭要素に乗せる仕様なので、レスポンスは
  /// `List<dynamic>` で受け取って [NarouSearchResponse] に詰め替える。
  Future<NarouSearchResponse> search(NarouSearchOptions opts) {
    return _limiter.run<NarouSearchResponse>(() async {
      final Map<String, dynamic> qp = <String, dynamic>{
        'out': 'json',
        ...opts.toQueryParameters(),
      };
      final Response<dynamic> res = await _dio.get<dynamic>(
        '/',
        queryParameters: qp,
      );
      return _parseSearch(res.data);
    });
  }

  /// 作品詳細を取得。複数 ncode をハイフン連結して 1 リクエストにまとめる
  /// （API 仕様で `ncode=ncode1-ncode2-...` 形式）。最大 100 件を上限とする。
  Future<List<NarouWorkSummary>> detail(List<String> ncodes) {
    if (ncodes.isEmpty) {
      return Future<List<NarouWorkSummary>>.value(const <NarouWorkSummary>[]);
    }
    if (ncodes.length > 100) {
      throw ArgumentError.value(
        ncodes.length,
        'ncodes.length',
        'must be <= 100',
      );
    }
    return _limiter.run<List<NarouWorkSummary>>(() async {
      final Map<String, dynamic> qp = <String, dynamic>{
        'out': 'json',
        'ncode': ncodes.join('-'),
        'lim': '100',
      };
      final Response<dynamic> res = await _dio.get<dynamic>(
        '/',
        queryParameters: qp,
      );
      final NarouSearchResponse parsed = _parseSearch(res.data);
      return parsed.works;
    });
  }

  /// 単一 ncode の詳細取得。`detail([ncode])` の薄いラッパ。
  Future<NarouWorkDetail> detailOne(String ncode) async {
    final List<NarouWorkSummary> all = await detail(<String>[ncode]);
    if (all.isEmpty) {
      throw NarouResponseError(
        'no detail returned for ncode=$ncode',
      );
    }
    return NarouWorkDetail(summary: all.first);
  }

  /// ランキング取得。`rankget` は本来 `api.syosetu.com/rank/rankget/`
  /// なので、コンストラクタの `baseUrl` ではなく **絶対 URL** で叩く。
  Future<List<NarouRankEntry>> rankget(
    NarouRankingType type,
    DateTime date,
  ) {
    return _limiter.run<List<NarouRankEntry>>(() async {
      // YYYYMMDD-<suffix>
      final String y = date.year.toString().padLeft(4, '0');
      final String m = date.month.toString().padLeft(2, '0');
      final String d = date.day.toString().padLeft(2, '0');
      final String rtype = '$y$m$d-${type.pathSuffix}';
      final Uri url = _baseUrl.replace(
        path: '/rank/rankget/',
        queryParameters: <String, String>{'out': 'json', 'rtype': rtype},
      );
      final Response<dynamic> res = await _dio.getUri<dynamic>(url);
      final dynamic data = res.data;
      if (data is! List) {
        throw NarouResponseError(
          'rankget: expected list, got ${data.runtimeType}',
        );
      }
      final List<NarouRankEntry> out = <NarouRankEntry>[];
      for (final dynamic raw in data) {
        if (raw is! Map) continue;
        final String? nc = raw['ncode'] as String?;
        final int? rank = _asInt(raw['rank']);
        final int? pt = _asInt(raw['pt']);
        if (nc == null || rank == null) continue;
        out.add(NarouRankEntry(ncode: nc, rank: rank, pt: pt ?? 0));
      }
      out.sort(
        (NarouRankEntry a, NarouRankEntry b) => a.rank.compareTo(b.rank),
      );
      return out;
    });
  }

  // ─── parsing helpers ─────────────────────────────────────────────────

  NarouSearchResponse _parseSearch(dynamic data) {
    if (data is! List) {
      throw NarouResponseError(
        'search: expected list, got ${data.runtimeType}',
      );
    }
    int allCount = 0;
    final List<NarouWorkSummary> works = <NarouWorkSummary>[];
    for (int i = 0; i < data.length; i++) {
      final dynamic raw = data[i];
      if (raw is! Map) continue;
      if (i == 0 && raw.containsKey('allcount')) {
        allCount = _asInt(raw['allcount']) ?? 0;
        continue;
      }
      works.add(_mapWorkSummary(raw, entryIndex: i));
    }
    return NarouSearchResponse(allCount: allCount, works: works);
  }

  /// 1 件分の JSON → [NarouWorkSummary] マッピング。
  ///
  /// `narou-novel-source` spec "Defensive mapping":
  /// **必須は `ncode` と `title` のみ**。それ以外は欠損許容で安全な
  /// default にフォールバックし、Unknown フィールドは無視する。
  NarouWorkSummary _mapWorkSummary(
    Map<dynamic, dynamic> raw, {
    int? entryIndex,
  }) {
    final String? ncode = (raw['ncode'] as String?)?.toLowerCase();
    final String? title = raw['title'] as String?;
    if (ncode == null || ncode.isEmpty) {
      throw NarouResponseError(
        'missing ncode in search response',
        entryIndex: entryIndex,
      );
    }
    if (title == null) {
      throw NarouResponseError(
        'missing title for ncode=$ncode',
        entryIndex: entryIndex,
      );
    }
    final List<String> keywords = _splitKeywords(raw['keyword']);
    return NarouWorkSummary(
      ncode: ncode,
      title: title,
      site: site,
      writer: (raw['writer'] as String?) ?? '',
      story: (raw['story'] as String?) ?? '',
      keywords: keywords,
      genreCode: _asInt(raw['genre']),
      bigGenreCode: _asInt(raw['biggenre']),
      generalAllNo: _asInt(raw['general_all_no']) ?? 0,
      length: _asInt(raw['length']) ?? 0,
      novelType: _asInt(raw['novel_type']) ?? 1,
      end: _asInt(raw['end']) ?? 0,
      lastUp: _parseNarouDate(raw['general_lastup']),
    );
  }

  static List<String> _splitKeywords(dynamic raw) {
    if (raw is! String || raw.isEmpty) return const <String>[];
    return raw
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _parseNarouDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    // なろう API は "YYYY-MM-DD HH:mm:ss" 形式（JST）を返す。
    try {
      final String normalized = raw.replaceFirst(' ', 'T');
      return DateTime.tryParse('$normalized+09:00');
    } catch (_) {
      return null;
    }
  }
}
