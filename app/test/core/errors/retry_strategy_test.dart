import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/retry_strategy.dart';

/// Deterministic RNG seeded for reproducibility.
math.Random _seededRng() => math.Random(42);

void main() {
  group('RetryStrategy factories', () {
    test('bounded(0) throws ArgumentError', () {
      expect(
        () => RetryStrategy.bounded(0),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'maxAttempts'),
        ),
      );
    });

    test('bounded(-1) throws ArgumentError', () {
      expect(() => RetryStrategy.bounded(-1), throwsArgumentError);
    });

    test('indefinite and none are const-constructible', () {
      const indef = RetryStrategy.indefinite();
      const noop = RetryStrategy.none();
      expect(indef, isA<RetryStrategy>());
      expect(noop, isA<RetryStrategy>());
    });
  });

  group('withRetry — happy path & give-up behaviour', () {
    test('successful first attempt invokes task exactly once', () async {
      var calls = 0;
      final result = await withRetry(() async {
        calls++;
        return 42;
      }, RetryStrategy.bounded(3));
      expect(result, 42);
      expect(calls, 1);
    });

    test('none retries zero times even for retriable errors', () async {
      var calls = 0;
      await expectLater(
        withRetry(() async {
          calls++;
          throw const NetworkUnreachableError(message: 'x');
        }, const RetryStrategy.none()),
        throwsA(isA<NetworkUnreachableError>()),
      );
      expect(calls, 1);
    });

    test('bounded(N) gives up after exactly N attempts', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          () async {
            calls++;
            throw const RateLimitError(message: 'x');
          },
          RetryStrategy.bounded(3),
          sleep: (_) async {},
        ),
        throwsA(isA<RateLimitError>()),
      );
      expect(calls, 3);
    });

    test('three failures then success follow 1s / 2s / 4s waits', () {
      fakeAsync((async) {
        final waits = <Duration>[];
        var calls = 0;
        String? settled;
        unawaited(
          withRetry<String>(
            () async {
              calls++;
              if (calls <= 3) {
                throw const UpstreamUnavailableError(message: 'x');
              }
              return 'ok';
            },
            RetryStrategy.bounded(5),
            initialDelay: const Duration(seconds: 1),
            jitter: 0.0,
            sleep: (d) async {
              waits.add(d);
            },
          ).then((value) => settled = value),
        );
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(calls, 4);
        expect(waits, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
        ]);
        expect(settled, 'ok');
      });
    });
  });

  group('withRetry — default predicate filters non-retriable errors', () {
    final nonRetriable = <AppError>[
      const RobotsDisallowedError(message: 'x', path: '/'),
      const SiteConsentRequiredError(message: 'x', site: 'kakuyomu'),
      const HtmlParseError(message: 'x'),
      FileNotFoundError(message: 'x', uri: Uri.parse('file:///a')),
      const UnsupportedFormatError(message: 'x'),
      const StorageQuotaError(message: 'x'),
      UnknownError(const FormatException('x')),
    ];

    for (final error in nonRetriable) {
      test('${error.runtimeType} is not retried', () async {
        var calls = 0;
        await expectLater(
          withRetry(
            () async {
              calls++;
              throw error;
            },
            RetryStrategy.bounded(5),
            sleep: (_) async {},
          ),
          throwsA(isA<AppError>()),
        );
        expect(calls, 1);
      });
    }

    test('non-AppError throwables are not retried', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          () async {
            calls++;
            throw const FormatException('not appError');
          },
          RetryStrategy.bounded(3),
          sleep: (_) async {},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1);
    });

    test('custom shouldRetry override is respected', () async {
      var calls = 0;
      final result = await withRetry(
        () async {
          calls++;
          if (calls < 3) throw const HtmlParseError(message: 'x');
          return 'ok';
        },
        RetryStrategy.bounded(5),
        shouldRetry: (e) => e is HtmlParseError,
        sleep: (_) async {},
      );
      expect(result, 'ok');
      expect(calls, 3);
    });
  });

  group('withRetry — RateLimitError.retryAfter', () {
    test('retryAfter overrides exponential backoff', () {
      fakeAsync((async) {
        final waits = <Duration>[];
        var calls = 0;
        unawaited(
          withRetry<String>(
            () async {
              calls++;
              if (calls == 1) {
                throw const RateLimitError(
                  message: 'x',
                  retryAfter: Duration(seconds: 30),
                );
              }
              return 'ok';
            },
            RetryStrategy.bounded(3),
            initialDelay: const Duration(seconds: 1),
            jitter: 0.5,
            sleep: (d) async {
              waits.add(d);
            },
          ),
        );
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect(waits, [const Duration(seconds: 30)]);
        expect(calls, 2);
      });
    });

    test('retryAfter null falls back to exponential', () {
      fakeAsync((async) {
        final waits = <Duration>[];
        var calls = 0;
        unawaited(
          withRetry<String>(
            () async {
              calls++;
              if (calls == 1) {
                throw const RateLimitError(message: 'x', retryAfter: null);
              }
              return 'ok';
            },
            RetryStrategy.bounded(3),
            initialDelay: const Duration(seconds: 1),
            jitter: 0.0,
            sleep: (d) async {
              waits.add(d);
            },
          ),
        );
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(waits, [const Duration(seconds: 1)]);
      });
    });
  });

  group('withRetry — backoff bounds', () {
    test('jitter=0 yields exact delays', () {
      fakeAsync((async) {
        final waits = <Duration>[];
        var calls = 0;
        unawaited(
          withRetry<String>(
            () async {
              calls++;
              if (calls < 5) throw const UpstreamUnavailableError(message: 'x');
              return 'ok';
            },
            RetryStrategy.bounded(10),
            initialDelay: const Duration(seconds: 1),
            maxDelay: const Duration(minutes: 10),
            jitter: 0.0,
            sleep: (d) async {
              waits.add(d);
            },
          ),
        );
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(waits, [
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
          const Duration(seconds: 8),
        ]);
      });
    });

    test('maxDelay=5min clamps 2^9=512s wait to 300s', () {
      fakeAsync((async) {
        Duration? lastWait;
        var calls = 0;
        unawaited(
          withRetry<String>(
            () async {
              calls++;
              if (calls < 11) {
                throw const UpstreamUnavailableError(message: 'x');
              }
              return 'ok';
            },
            RetryStrategy.bounded(20),
            initialDelay: const Duration(seconds: 1),
            maxDelay: const Duration(minutes: 5),
            jitter: 0.0,
            sleep: (d) async {
              lastWait = d;
            },
          ),
        );
        async.elapse(const Duration(hours: 1));
        async.flushMicrotasks();
        // The 10th wait would naively be 2^9 = 512s; clamped to 300s.
        expect(lastWait, const Duration(minutes: 5));
      });
    });

    test('jitter > 0 keeps total wait within ±jitter * delay', () {
      fakeAsync((async) {
        final waits = <Duration>[];
        var calls = 0;
        unawaited(
          withRetry<String>(
            () async {
              calls++;
              if (calls < 4) throw const NetworkUnreachableError(message: 'x');
              return 'ok';
            },
            RetryStrategy.bounded(10),
            initialDelay: const Duration(seconds: 1),
            jitter: 0.2,
            random: _seededRng(),
            sleep: (d) async {
              waits.add(d);
            },
          ),
        );
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(waits.length, 3);
        const baseline = [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
        ];
        for (var i = 0; i < waits.length; i++) {
          final base = baseline[i].inMicroseconds;
          expect(
            waits[i].inMicroseconds,
            greaterThanOrEqualTo((base * 0.8).round()),
          );
          expect(
            waits[i].inMicroseconds,
            lessThanOrEqualTo((base * 1.2).round()),
          );
        }
      });
    });

    test('jitter < 0 throws ArgumentError', () async {
      await expectLater(
        withRetry(() async => 1, const RetryStrategy.none(), jitter: -0.1),
        throwsArgumentError,
      );
    });
  });

  group('withRetry — indefinite', () {
    test('indefinite tolerates 12 retriable failures', () {
      fakeAsync((async) {
        var calls = 0;
        String? settled;
        unawaited(
          withRetry<String>(
            () async {
              calls++;
              if (calls < 13) throw const RateLimitError(message: 'x');
              return 'ok';
            },
            const RetryStrategy.indefinite(),
            initialDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 1),
            jitter: 0.0,
            sleep: (_) async {},
          ).then((value) => settled = value),
        );
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(calls, 13);
        expect(settled, 'ok');
      });
    });

    test('indefinite stops when shouldRetry returns false', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          () async {
            calls++;
            if (calls == 1) {
              throw const NetworkUnreachableError(message: 'x');
            }
            throw const HtmlParseError(message: 'y');
          },
          const RetryStrategy.indefinite(),
          initialDelay: Duration.zero,
          sleep: (_) async {},
        ),
        throwsA(isA<HtmlParseError>()),
      );
      expect(calls, 2);
    });
  });
}
