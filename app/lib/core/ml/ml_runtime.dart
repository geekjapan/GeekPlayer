import 'package:flutter/foundation.dart';

import 'ml_backend.dart';
import 'ml_capabilities.dart';
import 'ml_model_state.dart';

/// Resolves the current [TargetPlatform]. Injected so tests can exercise any
/// platform branch without `dart:io`.
typedef TargetPlatformResolver = TargetPlatform Function();

/// Probes whether a given execution-provider [MlBackend] is usable now.
typedef ExecutionProviderProbe = Future<bool> Function(MlBackend backend);

/// Resolves whether the upscaling model is present.
typedef ModelStateResolver = Future<MlModelState> Function();

/// Resolves whether the experimental AI-upscaling feature is enabled.
typedef ExperimentalFlagResolver = Future<bool> Function();

TargetPlatform _defaultPlatform() => defaultTargetPlatform;

// Floor defaults: nothing is implemented/enabled yet, so probe() resolves to
// the bicubicCpu floor — matching the only shipped upscaler (CpuImageUpscaler).
Future<bool> _noExecutionProviders(MlBackend _) async => false;
Future<MlModelState> _modelAbsent() async => MlModelState.absent;
Future<bool> _experimentalOff() async => false;

/// Resolves the platform-preferred backend and probes the effective backend
/// per ADR-0007 (preferred → ortCpu → bicubicCpu, gated by experimental flag
/// and model availability).
class MlRuntime {
  const MlRuntime({
    TargetPlatformResolver? platform,
    ExecutionProviderProbe? executionProviderProbe,
    ModelStateResolver? modelState,
    ExperimentalFlagResolver? experimentalFlag,
  }) : _platform = platform ?? _defaultPlatform,
       _epProbe = executionProviderProbe ?? _noExecutionProviders,
       _modelState = modelState ?? _modelAbsent,
       _experimentalFlag = experimentalFlag ?? _experimentalOff;

  final TargetPlatformResolver _platform;
  final ExecutionProviderProbe _epProbe;
  final ModelStateResolver _modelState;
  final ExperimentalFlagResolver _experimentalFlag;

  /// The platform-preferred backend (intent only; not necessarily available).
  MlBackend preferredBackend() {
    switch (_platform()) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return MlBackend.coremlEp;
      case TargetPlatform.android:
        return MlBackend.nnapiEp;
      case TargetPlatform.windows:
        return MlBackend.directmlEp;
      case TargetPlatform.linux:
        return MlBackend.ortCpu;
      case TargetPlatform.fuchsia:
        return MlBackend.bicubicCpu;
    }
  }

  /// Resolves the effective backend via the ADR-0007 fallback chain.
  ///
  /// Never throws: `bicubicCpu` is always reachable.
  Future<MlCapabilities> probe() async {
    final MlBackend preferred = preferredBackend();
    final bool experimental = await _experimentalFlag();
    final MlModelState model = await _modelState();

    MlCapabilities floor(String reason) => MlCapabilities(
      preferred: preferred,
      effective: MlBackend.bicubicCpu,
      modelState: model,
      experimentalEnabled: experimental,
      reason: reason,
    );

    if (!experimental) {
      return floor('experimental AI upscaling is disabled');
    }
    if (model == MlModelState.absent) {
      return floor('upscaling model is not downloaded');
    }

    MlCapabilities resolved(MlBackend effective, String reason) =>
        MlCapabilities(
          preferred: preferred,
          effective: effective,
          modelState: model,
          experimentalEnabled: experimental,
          reason: reason,
        );

    final bool preferredIsGpuEp =
        preferred != MlBackend.ortCpu && preferred != MlBackend.bicubicCpu;
    if (preferredIsGpuEp && await _epProbe(preferred)) {
      return resolved(preferred, 'using preferred execution provider');
    }
    if (await _epProbe(MlBackend.ortCpu)) {
      return resolved(
        MlBackend.ortCpu,
        'preferred EP unavailable; using ONNX Runtime CPU',
      );
    }
    return resolved(
      MlBackend.bicubicCpu,
      'no accelerated backend available; using bicubic CPU',
    );
  }
}
