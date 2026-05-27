import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/network/rate_limiter.dart';
import 'package:geekplayer/core/novel/models/site.dart';
import 'package:geekplayer/core/novel/models/work_query.dart';
import 'package:geekplayer/core/storage/database.dart';
import 'package:geekplayer/features/novel/data/consent_repository.dart';
import 'package:geekplayer/features/novel_narou/data/narou_api_client.dart';
import 'package:geekplayer/features/novel_narou/data/narou_episode_fetcher.dart';
import 'package:geekplayer/features/novel_narou/data/narou_r18_novel_repository.dart';

class _FakeInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler h) {
    h.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <dynamic>[
          <String, dynamic>{'allcount': 0},
        ],
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late ConsentRepository consent;
  late NarouApiClient client;
  late NarouEpisodeFetcher fetcher;
  late RateLimiter limiter;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    consent = ConsentRepository(db.siteConsentsDao);
    limiter = RateLimiter(rate: 1000, burst: 1000, maxConcurrency: 4);
    final Dio dio = Dio()..interceptors.add(_FakeInterceptor());
    client = NarouApiClient(
      baseUrl: Uri.parse('https://api.syosetu.com/novel18api/api/'),
      dio: dio,
      limiter: limiter,
      site: Site.noc,
      appVersion: '1.0.0',
    );
    fetcher = NarouEpisodeFetcher(
      dio: Dio()..interceptors.add(_FakeInterceptor()),
      limiter: limiter,
      bodyBaseUrl: Uri.parse('https://novel18.syosetu.com'),
      appVersion: '1.0.0',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('未同意での `create` は StateError', () async {
    final StreamController<bool> ctrl = StreamController<bool>.broadcast();
    expect(
      () => NarouR18NovelRepository.create(
        apiClient: client,
        episodeFetcher: fetcher,
        consentRepository: consent,
        consentStream: ctrl.stream,
      ),
      throwsA(isA<StateError>()),
    );
    await ctrl.close();
  });

  test('同意後の `create` は成功し、search が StateError を投げない', () async {
    await consent.grant(Site.noc);
    final StreamController<bool> ctrl = StreamController<bool>.broadcast();
    final NarouR18NovelRepository repo = await NarouR18NovelRepository.create(
      apiClient: client,
      episodeFetcher: fetcher,
      consentRepository: consent,
      consentStream: ctrl.stream,
    );
    // 通常の search は (本テストでは中身 0 件だが) StateError は出ない。
    await repo.searchWorks(
      const WorkQueryWrapper(),
    );
    await repo.dispose();
    await ctrl.close();
  });

  test('revoke イベントで以降のメソッドが StateError', () async {
    await consent.grant(Site.noc);
    final StreamController<bool> ctrl = StreamController<bool>.broadcast();
    final NarouR18NovelRepository repo = await NarouR18NovelRepository.create(
      apiClient: client,
      episodeFetcher: fetcher,
      consentRepository: consent,
      consentStream: ctrl.stream,
    );
    // 受信機構が動いている前提で revoke イベントを流す。
    ctrl.add(false);
    // microtask が回るのを待つ
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      () => repo.searchWorks(const WorkQueryWrapper()),
      throwsA(isA<StateError>()),
    );
    await repo.dispose();
    await ctrl.close();
  });
}

/// `searchWorks` に渡す最小の WorkQuery（subclass を経由しない）。
class WorkQueryWrapper extends WorkQuery {
  const WorkQueryWrapper() : super(site: Site.noc);
}
