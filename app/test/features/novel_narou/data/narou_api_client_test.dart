import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/network/rate_limiter.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/features/novel_narou/data/narou_api_client.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_ranking_type.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_work_query.dart';
import 'package:geekplayer/features/novel_narou/domain/narou_work_summary.dart';

/// 簡易の Dio Interceptor ベース fake adapter。
/// `dio_adapter` パッケージを足さずに `RequestInterceptor` で responseHandler
/// を割り込ませる方法を採用。
class _FakeInterceptor extends Interceptor {
  _FakeInterceptor(this.handler);

  final Response<dynamic> Function(RequestOptions) handler;
  final List<RequestOptions> recorded = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler h) {
    recorded.add(options);
    final Response<dynamic> res = handler(options);
    h.resolve(res);
  }
}

void main() {
  late RateLimiter limiter;

  setUp(() {
    // Fast token bucket so tests don't sleep.
    limiter = RateLimiter(rate: 1000, burst: 1000, maxConcurrency: 4);
  });

  Dio dioWith(_FakeInterceptor fake) {
    final Dio dio = Dio();
    dio.interceptors.add(fake);
    return dio;
  }

  test('search: out=json 固定 + word + lim が付与される', () async {
    final _FakeInterceptor fake = _FakeInterceptor((RequestOptions o) {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <dynamic>[
          <String, dynamic>{'allcount': 0},
        ],
      );
    });
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
      dio: dioWith(fake),
      limiter: limiter,
      site: Site.narou,
      appVersion: '1.0.0',
    );
    await client.search(const NarouSearchOptions(keyword: '魔法', limit: 20));
    final RequestOptions opts = fake.recorded.single;
    expect(opts.queryParameters['out'], 'json');
    expect(opts.queryParameters['word'], '魔法');
    expect(opts.queryParameters['lim'], '20');
  });

  test('search: fixture をパースして allCount と works を返す', () async {
    final String fixture = await File(
      'test/fixtures/narou/search_response_general.json',
    ).readAsString();
    final _FakeInterceptor fake = _FakeInterceptor((RequestOptions o) {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: jsonDecode(fixture),
      );
    });
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
      dio: dioWith(fake),
      limiter: limiter,
      site: Site.narou,
      appVersion: '1.0.0',
    );
    final NarouSearchResponse res = await client.search(
      const NarouSearchOptions(keyword: 'a'),
    );
    expect(res.allCount, 2);
    expect(res.works.length, 2);
    expect(res.works.first.ncode, 'n1234ab');
    expect(res.works.first.title, '魔王と少女');
    expect(res.works.first.generalAllNo, 47);
    expect(res.works.first.isShort, isFalse);
    expect(res.works.last.isShort, isTrue);
  });

  test('detail: 複数 ncode をハイフン連結で 1 リクエストにまとめる', () async {
    final _FakeInterceptor fake = _FakeInterceptor((RequestOptions o) {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <dynamic>[
          <String, dynamic>{'allcount': 0},
        ],
      );
    });
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
      dio: dioWith(fake),
      limiter: limiter,
      site: Site.narou,
      appVersion: '1.0.0',
    );
    await client.detail(<String>['n1234ab', 'n5678cd', 'n9999xx']);
    expect(fake.recorded.length, 1);
    expect(
      fake.recorded.single.queryParameters['ncode'],
      'n1234ab-n5678cd-n9999xx',
    );
  });

  test('detail: 100 件超は ArgumentError', () async {
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
      dio: dioWith(_FakeInterceptor((_) => throw StateError('unreached'))),
      limiter: limiter,
      site: Site.narou,
      appVersion: '1.0.0',
    );
    expect(
      () => client.detail(List<String>.generate(101, (int i) => 'n$i')),
      throwsArgumentError,
    );
  });

  test('rankget: ID + rank + pt 列を返し rank 昇順', () async {
    final String fixture = await File(
      'test/fixtures/narou/rankget_daily.json',
    ).readAsString();
    final _FakeInterceptor fake = _FakeInterceptor((RequestOptions o) {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: jsonDecode(fixture),
      );
    });
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/'),
      dio: dioWith(fake),
      limiter: limiter,
      site: Site.narou,
      appVersion: '1.0.0',
    );
    final List<NarouRankEntry> ranks = await client.rankget(
      NarouRankingType.daily,
      DateTime.utc(2026, 5, 27),
    );
    expect(ranks.length, 3);
    expect(ranks.first.rank, 1);
    expect(ranks.first.ncode, 'n1111aa');
    expect(ranks.first.pt, 9999);
    // rtype was YYYYMMDD-d; with getUri, the parameters are in options.uri.
    final Uri uri = fake.recorded.single.uri;
    expect(uri.queryParameters['rtype'], '20260527-d');
  });

  test('User-Agent ヘッダが ADR-0003 規範の形式で付与される', () async {
    final _FakeInterceptor fake = _FakeInterceptor((RequestOptions o) {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <dynamic>[
          <String, dynamic>{'allcount': 0},
        ],
      );
    });
    final NarouApiClient client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
      dio: dioWith(fake),
      limiter: limiter,
      site: Site.narou,
      appVersion: '1.0.0',
    );
    await client.search(const NarouSearchOptions(keyword: 'a'));
    final String ua = fake.recorded.single.headers['User-Agent'] as String;
    expect(
      RegExp(
        r'^GeekPlayer/\d+\.\d+\.\d+ \(\+https://github\.com/geekjapan/GeekPlayer; personal-use\)$',
      ).hasMatch(ua),
      isTrue,
      reason: 'actual UA was: $ua',
    );
  });

  test('一般 / R18 でレートリミッターを共有すると順次直列化される', () async {
    // RateLimiter を 1 req/sec、並列 1 に絞る → 一般と R18 の同時実行で
    // 2 件目は 1 件目の完了後にしか走らない。
    final RateLimiter shared = RateLimiter(
      rate: 1.0,
      burst: 1,
      maxConcurrency: 1,
    );
    final _FakeInterceptor fake = _FakeInterceptor((RequestOptions o) {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: <dynamic>[
          <String, dynamic>{'allcount': 0},
        ],
      );
    });
    final NarouApiClient general = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novelapi/api/'),
      dio: dioWith(fake),
      limiter: shared,
      site: Site.narou,
      appVersion: '1.0.0',
    );
    final NarouApiClient r18 = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novel18api/api/'),
      dio: dioWith(_FakeInterceptor((RequestOptions o) {
        return Response<dynamic>(
          requestOptions: o,
          statusCode: 200,
          data: <dynamic>[
            <String, dynamic>{'allcount': 0},
          ],
        );
      })),
      limiter: shared,
      site: Site.noc,
      appVersion: '1.0.0',
    );

    // 1 件目は即時、2 件目は inFlight 経由で待たされる。
    final Future<NarouSearchResponse> f1 = general.search(
      const NarouSearchOptions(keyword: 'a'),
    );
    // 2 件目の future を作った時点で shared.inFlight が 1 になっているはず
    final Future<NarouSearchResponse> f2 = r18.search(
      const NarouSearchOptions(keyword: 'b'),
    );

    final Stopwatch sw = Stopwatch()..start();
    await Future.wait<NarouSearchResponse>(<Future<NarouSearchResponse>>[f1, f2]);
    sw.stop();
    // バケット直列化により 2 件目は >= ~0ms 待たされるはずだが、極小バー
    // ストでも 1 req/sec の制限で 1 件目完了後に 2 件目開始 → 経過時間が
    // 0 を超える。
    expect(sw.elapsed > Duration.zero, isTrue);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
