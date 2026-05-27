import 'dart:async';
import 'dart:collection';

/// Token-bucket rate limiter with a concurrency ceiling.
///
/// Backs ADR-0001 §取得方針-3 (kakuyomu = `rate: 0.5, burst: 1,
/// maxConcurrency: 1`) and ADR-0003 (`*.syosetu.com` = `rate: 1.0,
/// burst: 5, maxConcurrency: 4`). One instance per `Site` is registered
/// in Riverpod by the responsible-fetching wiring layer.
///
/// Algorithm:
/// 1. Each [run] call blocks until the bucket has ≥ 1 token AND fewer
///    than [maxConcurrency] tasks are in flight.
/// 2. Tokens are refilled continuously at [rate] tokens / second, capped
///    at [burst]. Refilling uses a lazy "elapsed since last update"
///    calculation so we don't run a Timer in the background.
/// 3. Tasks are FIFO — the next waiter is awoken whenever a token
///    becomes available or a slot is freed.
class RateLimiter {
  RateLimiter({
    required this.rate,
    required this.burst,
    required this.maxConcurrency,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _tokens = burst.toDouble() {
    if (rate <= 0) {
      throw ArgumentError.value(rate, 'rate', 'must be > 0');
    }
    if (burst < 1) {
      throw ArgumentError.value(burst, 'burst', 'must be >= 1');
    }
    if (maxConcurrency < 1) {
      throw ArgumentError.value(
        maxConcurrency,
        'maxConcurrency',
        'must be >= 1',
      );
    }
    _lastRefill = _now();
  }

  /// Token replenishment rate in tokens / second.
  final double rate;

  /// Maximum bucket capacity.
  final int burst;

  /// In-flight task ceiling.
  final int maxConcurrency;

  final DateTime Function() _now;

  double _tokens;
  late DateTime _lastRefill;
  int _inFlight = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  /// Run [task] under the limiter. Returns whatever [task] returns.
  ///
  /// The function does NOT swallow exceptions; on failure the token /
  /// slot are still released so subsequent tasks are not starved.
  Future<T> run<T>(Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _release();
    }
  }

  /// Lower-level handle for callers (typically Dio interceptors) that
  /// cannot wrap a single `Future` around their work. Acquires a token
  /// + slot and returns a release callback. The caller MUST invoke the
  /// returned callback exactly once when the operation completes
  /// (success OR failure).
  Future<void Function()> acquirePermit() async {
    await _acquire();
    bool released = false;
    return () {
      if (released) return;
      released = true;
      _release();
    };
  }

  /// Snapshot of token count for tests. Not part of the public API.
  double get tokensForTest {
    _refill();
    return _tokens;
  }

  /// Snapshot of in-flight count for tests.
  int get inFlightForTest => _inFlight;

  Future<void> _acquire() async {
    while (true) {
      _refill();
      if (_inFlight < maxConcurrency && _tokens >= 1.0) {
        _tokens -= 1.0;
        _inFlight += 1;
        return;
      }
      // Either no tokens or no slots — wait. Compute wake time so we
      // don't spin: the sooner of (refill enough for 1 token) /
      // (next slot release).
      final Completer<void> waiter = Completer<void>();
      _waiters.add(waiter);

      if (_inFlight >= maxConcurrency) {
        // Slot-bound — wait until a release wakes us.
        await waiter.future;
        continue;
      }

      // Token-bound — schedule a wake based on refill rate.
      final double needed = 1.0 - _tokens;
      final int waitMs = (needed / rate * 1000).ceil();
      // Race the timer against an external wakeup (e.g. _release()).
      Timer? timer;
      timer = Timer(Duration(milliseconds: waitMs), () {
        if (!waiter.isCompleted) waiter.complete();
      });
      await waiter.future;
      timer.cancel();
    }
  }

  void _release() {
    _inFlight -= 1;
    if (_inFlight < 0) _inFlight = 0;
    _wakeNext();
  }

  void _refill() {
    final DateTime now = _now();
    final double elapsed =
        now.difference(_lastRefill).inMicroseconds / 1000000.0;
    if (elapsed <= 0) return;
    _tokens = (_tokens + elapsed * rate).clamp(0.0, burst.toDouble());
    _lastRefill = now;
  }

  void _wakeNext() {
    while (_waiters.isNotEmpty) {
      final Completer<void> next = _waiters.removeFirst();
      if (!next.isCompleted) {
        next.complete();
        return;
      }
    }
  }
}
