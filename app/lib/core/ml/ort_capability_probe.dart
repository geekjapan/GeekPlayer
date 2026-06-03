import 'package:onnxruntime/onnxruntime.dart';

import 'ml_backend.dart';
import 'ml_runtime.dart' show ExecutionProviderProbe;

/// Whether the ONNX Runtime native library loads and initializes here.
///
/// This answers only "does ORT initialize on this platform" — sufficient for
/// the CPU execution provider, which ORT always provides once loaded. Never
/// throws.
bool ortRuntimeAvailable() {
  try {
    OrtEnv.instance.init();
    return OrtEnv.version.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// An [ExecutionProviderProbe] backed by ONNX Runtime.
///
/// Reports `ortCpu` as available when ORT initializes. GPU execution providers
/// (CoreML / NNAPI / DirectML) stay unavailable here; enabling them is step 4
/// (`enable-gpu-execution-providers`).
Future<bool> ortCpuExecutionProviderProbe(MlBackend backend) async {
  if (backend == MlBackend.ortCpu) {
    return ortRuntimeAvailable();
  }
  return false;
}
