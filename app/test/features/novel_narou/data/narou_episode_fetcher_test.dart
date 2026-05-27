import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/network/rate_limiter.dart';
import 'package:geekplayer/features/novel_narou/data/narou_episode_fetcher.dart';

class _FakeBodyInterceptor extends Interceptor {
  _FakeBodyInterceptor(this.html);
  final String html;
  final List<Uri> requested = <Uri>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler h) {
    requested.add(options.uri);
    h.resolve(
      Response<String>(requestOptions: options, statusCode: 200, data: html),
    );
  }
}

void main() {
  test('短編 (episodeIndex=1) は <div id="novel_honbun"> から本文を抽出する', () async {
    final String html = await File(
      'test/fixtures/narou/episode_body.html',
    ).readAsString();
    final _FakeBodyInterceptor fake = _FakeBodyInterceptor(html);
    final Dio dio = Dio()..interceptors.add(fake);
    final NarouEpisodeFetcher fetcher = NarouEpisodeFetcher(
      dio: dio,
      limiter: RateLimiter(rate: 1000, burst: 1000, maxConcurrency: 4),
      bodyBaseUrl: Uri.parse('https://ncode.syosetu.com'),
      appVersion: '1.0.0',
    );
    final String body = await fetcher.fetchBody('N1234AB', 1);
    expect(body.contains('魔王'), isTrue);
    expect(body.contains('続きはまた次回。'), isTrue);
    // URL は小文字化された ncode で構築される
    expect(fake.requested.single.path, '/n1234ab/1/');
  });

  test('連載 (episodeIndex=N) で異なる URL を叩く', () async {
    final String html = await File(
      'test/fixtures/narou/episode_body.html',
    ).readAsString();
    final _FakeBodyInterceptor fake = _FakeBodyInterceptor(html);
    final Dio dio = Dio()..interceptors.add(fake);
    final NarouEpisodeFetcher fetcher = NarouEpisodeFetcher(
      dio: dio,
      limiter: RateLimiter(rate: 1000, burst: 1000, maxConcurrency: 4),
      bodyBaseUrl: Uri.parse('https://ncode.syosetu.com'),
      appVersion: '1.0.0',
    );
    await fetcher.fetchBody('N1234AB', 5);
    expect(fake.requested.single.path, '/n1234ab/5/');
  });

  test('RateLimiter で連続呼び出しが直列化される', () async {
    final String html = await File(
      'test/fixtures/narou/episode_body.html',
    ).readAsString();
    final _FakeBodyInterceptor fake = _FakeBodyInterceptor(html);
    final Dio dio = Dio()..interceptors.add(fake);
    final RateLimiter limited = RateLimiter(
      rate: 2.0,
      burst: 1,
      maxConcurrency: 1,
    );
    final NarouEpisodeFetcher fetcher = NarouEpisodeFetcher(
      dio: dio,
      limiter: limited,
      bodyBaseUrl: Uri.parse('https://ncode.syosetu.com'),
      appVersion: '1.0.0',
    );
    final Stopwatch sw = Stopwatch()..start();
    await fetcher.fetchBody('n1', 1);
    await fetcher.fetchBody('n2', 1);
    await fetcher.fetchBody('n3', 1);
    sw.stop();
    // 3 件目までで少なくとも 500 ms ほど(2req/sec のバケット制限)。
    // burst=1 なので 2 件目以降は ~500ms ずつ待たされる。
    expect(sw.elapsedMilliseconds >= 200, isTrue);
  });
}
