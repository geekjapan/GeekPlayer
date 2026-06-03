import 'package:flutter/foundation.dart';

import 'ml_backend.dart';

/// Describes the ML capabilities available on the current platform.
@immutable
class MlCapabilities {
  const MlCapabilities({required this.backend});

  /// The hardware accelerator backend selected for this platform.
  final MlBackend backend;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MlCapabilities &&
          runtimeType == other.runtimeType &&
          backend == other.backend;

  @override
  int get hashCode => backend.hashCode;

  @override
  String toString() => 'MlCapabilities(backend: $backend)';
}
