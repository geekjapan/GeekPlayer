import 'package:flutter/foundation.dart';

import 'ml_backend.dart';
import 'ml_capabilities.dart';

/// Resolves the current [TargetPlatform].
///
/// Injected into [MlRuntime] so that unit tests can exercise any
/// platform branch without requiring `dart:io`.
typedef TargetPlatformResolver = TargetPlatform Function();

TargetPlatform _defaultResolver() => defaultTargetPlatform;

/// Detects the runtime platform and exposes [MlCapabilities].
class MlRuntime {
  const MlRuntime({TargetPlatformResolver? resolver})
    : _resolver = resolver ?? _defaultResolver;

  final TargetPlatformResolver _resolver;

  /// Returns capabilities appropriate for the current platform.
  MlCapabilities describe() => MlCapabilities(backend: _selectBackend());

  MlBackend _selectBackend() {
    switch (_resolver()) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return MlBackend.coreml;
      case TargetPlatform.android:
        return MlBackend.nnapi;
      case TargetPlatform.windows:
        return MlBackend.tensorRt;
      case TargetPlatform.linux:
        return MlBackend.onnxRuntime;
      case TargetPlatform.fuchsia:
        return MlBackend.cpu;
    }
  }
}
