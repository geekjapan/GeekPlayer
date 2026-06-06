/// User-facing override for the AI upscaling execution backend (ADR-0007 step 4).
///
/// The override acts on the *preferred* backend only; `MlRuntime.probe()` still
/// validates availability and degrades to the bicubic CPU floor when the chosen
/// backend cannot run. The concrete GPU EP behind [forceGpu] is resolved from
/// the platform (iOS/macOS → CoreML, Android → NNAPI; elsewhere no GPU EP).
enum AiUpscaleBackendOverride {
  /// Use the platform-default preferred backend (no override).
  auto,

  /// Force the ONNX Runtime CPU execution provider (opt out of GPU).
  forceCpu,

  /// Force the platform's GPU execution provider (degrades if unavailable).
  forceGpu,
}
