/// Execution-provider-oriented backend used for ML image upscaling (ADR-0007).
enum MlBackend {
  /// ONNX Runtime CoreML execution provider (iOS / macOS).
  coremlEp,

  /// ONNX Runtime NNAPI execution provider (Android).
  nnapiEp,

  /// ONNX Runtime DirectML execution provider (Windows).
  directmlEp,

  /// ONNX Runtime CPU execution provider (cross-platform).
  ortCpu,

  /// Pure-Dart bicubic CPU upscaler — the universal floor, always available.
  bicubicCpu,
}
