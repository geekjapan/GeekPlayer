import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scaffold_messenger_key.g.dart';

/// Global, app-lifetime [GlobalKey] for the root [ScaffoldMessenger].
///
/// `MaterialApp.scaffoldMessengerKey` reads this so that `showErrorToast`
/// can enqueue [SnackBar]s without needing a [BuildContext] under an active
/// [Scaffold] subtree. Marked `keepAlive` because the key must outlive any
/// individual screen.
@Riverpod(keepAlive: true)
GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey(Ref ref) =>
    GlobalKey<ScaffoldMessengerState>();

/// Companion notifier that tracks recent toast dispatches so that
/// `showErrorToast` can de-duplicate identical errors fired within 1 second.
/// The state is `(runtimeType, message, timestamp)` for the most recent
/// dispatch; comparing the next dispatch against it is enough because the
/// dedup window is short.
@Riverpod(keepAlive: true)
class ToastDedupRegistry extends _$ToastDedupRegistry {
  @override
  ToastDedupEntry? build() => null;

  /// Returns `true` when [signature] matches the most recent dispatch and
  /// the last dispatch was at most [window] ago, in which case the caller
  /// SHOULD suppress the duplicate. Updates the stored entry as a side
  /// effect so that subsequent calls compare against `now`.
  bool shouldSuppress(
    ToastDedupSignature signature, {
    Duration window = const Duration(seconds: 1),
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now();
    final last = state;
    final suppress =
        last != null &&
        last.signature == signature &&
        stamp.difference(last.timestamp) < window;
    if (!suppress) {
      state = ToastDedupEntry(signature: signature, timestamp: stamp);
    }
    return suppress;
  }
}

/// Identity of a toast dispatch for de-duplication. Two dispatches are
/// "identical" when their [AppError] runtime type and message match.
class ToastDedupSignature {
  const ToastDedupSignature({required this.type, required this.message});

  final Type type;
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToastDedupSignature &&
          other.type == type &&
          other.message == message);

  @override
  int get hashCode => Object.hash(type, message);
}

/// Stored entry for [ToastDedupRegistry].
class ToastDedupEntry {
  const ToastDedupEntry({required this.signature, required this.timestamp});

  final ToastDedupSignature signature;
  final DateTime timestamp;
}
