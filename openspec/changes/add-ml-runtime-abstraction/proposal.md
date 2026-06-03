## Why

GeekPlayer v1.0 will ship on-device AI upscaling (Real-ESRGAN / waifu2x) that must
delegate to platform-native accelerators — CoreML on Apple, NNAPI on Android,
ONNX Runtime on Linux, TensorRT on Windows. Without a backend-agnostic abstraction
the feature code cannot be shared across platforms, and the v1.0 roadmap item
("抽象化レイヤを `core/ml/` に置く") remains blocked.

## What Changes

- New `app/lib/core/ml/` package: `MlBackend` enum, `MlCapabilities` value object,
  `UpscaleRequest` / `UpscaleResult` value objects, `ImageUpscaler` abstract interface,
  `MlRuntime` service (injectable platform detection), `PassthroughUpscaler`
  pure-Dart default implementation.
- New Riverpod providers: `mlRuntimeProvider`, `imageUpscalerProvider` (both
  keepAlive, codegen).
- New unit tests under `app/test/core/ml/` covering backend selection per platform,
  passthrough upscaling, and provider override.
- No native code added. No new user-visible UI strings. No drift schema changes.
  No heavy ML dependencies.

## Capabilities

### New Capabilities

- `ml-runtime`: Cross-platform ML runtime abstraction — platform detection, backend
  selection, upscale request/result types, and a CPU passthrough default.

### Modified Capabilities

(none)

## Non-goals

- Bundling Real-ESRGAN / waifu2x model weights.
- Writing native iOS / macOS / Android / Windows bridging code.
- GPU or NPU inference — the passthrough runs purely on CPU as a no-op placeholder.
- Any user-facing UI.
- Drift schema changes.

## Impact

- **New files**: `app/lib/core/ml/*.dart` (7 source files + 1 generated),
  `app/test/core/ml/*.dart` (3 test files).
- **No existing files modified** (net-new capability).
- **Dependencies**: no new pubspec entries — `flutter_riverpod`, `riverpod_annotation`,
  and `riverpod_generator` are already present (`app/pubspec.yaml:39-42,79`).
- **Affected specs**: new capability `ml-runtime` introduced via delta spec at
  `openspec/changes/add-ml-runtime-abstraction/specs/ml-runtime/spec.md`.
