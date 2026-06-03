/// Hardware accelerator backend used for ML inference.
enum MlBackend {
  /// CoreML (iOS / macOS).
  coreml,

  /// NNAPI (Android).
  nnapi,

  /// ONNX Runtime (Linux and cross-platform fallback).
  onnxRuntime,

  /// TensorRT (Windows).
  tensorRt,

  /// Pure-CPU fallback — no hardware acceleration.
  cpu,
}
