import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/scaffold_messenger_key.dart';

void main() {
  test('identical signature within 1s is suppressed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(toastDedupRegistryProvider.notifier);

    final sig = const ToastDedupSignature(
      type: NetworkUnreachableError,
      message: 'x',
    );
    final t0 = DateTime(2026, 5, 27, 12, 0, 0);

    expect(notifier.shouldSuppress(sig, now: t0), isFalse);
    expect(
      notifier.shouldSuppress(sig, now: t0.add(const Duration(milliseconds: 200))),
      isTrue,
    );
  });

  test('after the dedup window the same signature passes again', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(toastDedupRegistryProvider.notifier);

    final sig = const ToastDedupSignature(
      type: NetworkUnreachableError,
      message: 'x',
    );
    final t0 = DateTime(2026, 5, 27, 12, 0, 0);

    expect(notifier.shouldSuppress(sig, now: t0), isFalse);
    expect(
      notifier.shouldSuppress(sig, now: t0.add(const Duration(milliseconds: 1500))),
      isFalse,
    );
  });

  test('different message is not suppressed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(toastDedupRegistryProvider.notifier);

    final t0 = DateTime(2026, 5, 27, 12, 0, 0);
    expect(
      notifier.shouldSuppress(
        const ToastDedupSignature(type: NetworkUnreachableError, message: 'a'),
        now: t0,
      ),
      isFalse,
    );
    expect(
      notifier.shouldSuppress(
        const ToastDedupSignature(type: NetworkUnreachableError, message: 'b'),
        now: t0.add(const Duration(milliseconds: 100)),
      ),
      isFalse,
    );
  });

  test('different runtimeType is not suppressed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(toastDedupRegistryProvider.notifier);

    final t0 = DateTime(2026, 5, 27, 12, 0, 0);
    expect(
      notifier.shouldSuppress(
        const ToastDedupSignature(type: RateLimitError, message: 'm'),
        now: t0,
      ),
      isFalse,
    );
    expect(
      notifier.shouldSuppress(
        const ToastDedupSignature(type: NetworkUnreachableError, message: 'm'),
        now: t0.add(const Duration(milliseconds: 50)),
      ),
      isFalse,
    );
  });
}
