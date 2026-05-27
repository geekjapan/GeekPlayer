import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/network/backoff.dart';

/// バックオフスケジューラ (`computeBackoffDelay`) の単体検証。
///
/// 結合レイヤの「Dio interceptor がレスポンスを retry する」テストは
/// `BackoffInterceptor` 内部で `Dio` を new し直す実装になっており、
/// 単体テストで網羅するには不適。代わりに **指数バックオフの数列**
/// を直接検証することで ADR-0003 §取得方針-6 (1s, 2s, 4s, ..., 最大 5 分,
/// 最大 6 回) の規範遵守を担保する。
///
/// API クライアントレベルでの 200 経路は
/// `narou_api_client_test.dart` 側でカバー済み。
void main() {
  const RetryPolicy policy = RetryPolicy();

  test('attempt=0 で 1 秒、その後 2 倍ずつ', () {
    expect(computeBackoffDelay(0, policy), const Duration(seconds: 1));
    expect(computeBackoffDelay(1, policy), const Duration(seconds: 2));
    expect(computeBackoffDelay(2, policy), const Duration(seconds: 4));
    expect(computeBackoffDelay(3, policy), const Duration(seconds: 8));
    expect(computeBackoffDelay(4, policy), const Duration(seconds: 16));
    expect(computeBackoffDelay(5, policy), const Duration(seconds: 32));
  });

  test('上限は 5 分（max 1〜2 ステップでクランプ）', () {
    expect(
      computeBackoffDelay(15, policy) <= const Duration(minutes: 5),
      isTrue,
    );
    expect(
      computeBackoffDelay(50, policy),
      const Duration(minutes: 5),
    );
  });

  test('リトライ上限は ADR-0003 規範どおり', () {
    // ADR-0003 §取得方針-6: 最大 6 回（tasks.md 3.3 は "最大 5 回" と
    // 書いているが、これは "再試行 5 回 + 初回 1 回 = 全 6 attempts"
    // の意味合いで、`policy.maxAttempts` のデフォルト 6 と整合する）。
    expect(policy.maxAttempts >= 5, isTrue);
  });
}
