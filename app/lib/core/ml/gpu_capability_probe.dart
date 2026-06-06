import 'package:onnxruntime/onnxruntime.dart';

import 'ml_backend.dart';
import 'ort_capability_probe.dart' show ortRuntimeAvailable;

/// Whether a GPU execution provider can be appended on this host (ADR-0007 step 4).
///
/// Tries appending the EP to a throwaway [OrtSessionOptions] — no model or
/// inference session is created. Success means the native ONNX Runtime build
/// includes the EP; any failure (missing symbol, unsupported platform) is
/// caught and reported as unavailable. Never throws.
bool _gpuEpAvailable(MlBackend backend) {
  OrtSessionOptions? options;
  try {
    OrtEnv.instance.init();
    options = OrtSessionOptions();
    switch (backend) {
      case MlBackend.coremlEp:
        options.appendCoreMLProvider(CoreMLFlags.useNone);
        return true;
      case MlBackend.nnapiEp:
        options.appendNnapiProvider(NnapiFlags.useNone);
        return true;
      default:
        return false;
    }
  } catch (_) {
    return false;
  } finally {
    options?.release();
  }
}

/// GPU EP availability probe (CoreML / NNAPI). `directmlEp` is always
/// unavailable — the `onnxruntime` package's high-level API does not expose
/// DirectML, so Windows GPU falls through to ORT CPU via the fallback chain.
/// Never throws.
Future<bool> gpuExecutionProviderProbe(MlBackend backend) async {
  switch (backend) {
    case MlBackend.coremlEp:
    case MlBackend.nnapiEp:
      return _gpuEpAvailable(backend);
    default:
      // ortCpu / directmlEp / bicubicCpu — not a GPU EP this probe handles.
      return false;
  }
}

/// Combined CPU + GPU execution-provider probe for `MlRuntime`'s
/// `ExecutionProviderProbe` seam (ADR-0007 step 4). Reports `ortCpu` via ORT
/// initialization, `coremlEp`/`nnapiEp` via the GPU availability probe, and
/// `directmlEp` as always unavailable. Never throws.
Future<bool> combinedExecutionProviderProbe(MlBackend backend) async {
  switch (backend) {
    case MlBackend.ortCpu:
      return ortRuntimeAvailable();
    case MlBackend.coremlEp:
    case MlBackend.nnapiEp:
      return _gpuEpAvailable(backend);
    default:
      // directmlEp, bicubicCpu, etc.
      return false;
  }
}
