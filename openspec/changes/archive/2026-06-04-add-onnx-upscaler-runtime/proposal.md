## Why

ADR-0007 picks ONNX Runtime (ORT) as the single cross-platform inference bridge for AI image upscaling, with the ORT CPU execution provider as the verifiable-everywhere tier above the bicubic floor. Step 1 (`refactor-ml-runtime-effective-backend`) landed the preferred/effective backend seam with an injectable, always-false EP probe and a bicubic floor. There is still no actual ONNX inference: the `ortCpu` backend can be *named* but never *runs*. This change lands the first real inference path — an `OnnxImageUpscaler` on the ORT CPU EP — so the effective-backend machinery has something to resolve to and the integration is provable in CI before any GPU EP or model-distribution work.

## What Changes

- Add an `OnnxImageUpscaler` implementing `ImageUpscaler`: decode input bytes → preprocess to an NCHW float tensor → run an ONNX super-resolution model on the ORT **CPU execution provider** → postprocess the output tensor back to encoded image bytes, reporting `MlBackend.ortCpu`.
- Provide a concrete **`ortCpu` availability probe** that reports whether ONNX Runtime can initialize on the current platform, replacing step 1's always-false default when wired in. The probe is the real implementation behind `MlRuntime`'s existing injectable EP-probe seam — no change to `ml-runtime`'s requirements.
- Wire selection through the existing seam: when experimental is enabled **and** a model is present **and** `ortCpu` probes available, `imageUpscalerProvider` resolves to `OnnxImageUpscaler` (effective backend `ortCpu`); otherwise it stays the bicubic CPU floor (`CpuImageUpscaler`) — the shipped default is unchanged (experimental OFF, no model ⇒ bicubic).
- Add a tiny bundled ONNX model fixture (a minimal upscaling graph, e.g. a single `Resize`/`ConvTranspose` op) under test assets, plus a **CPU-EP inference smoke test** that proves real ORT inference runs and produces correctly-sized output. This test is runnable locally on macOS and in every CI job (no GPU needed).
- Model **input is injected** (a file path / bytes provided by the caller). This change does not download or manage models — `OnnxImageUpscaler` is given a model; sourcing it is step 3.

## Capabilities

### New Capabilities
- `onnx-upscaler-runtime`: ORT-backed image upscaling on the CPU execution provider — the `OnnxImageUpscaler`, its image↔tensor pre/postprocessing contract, the concrete `ortCpu` availability probe, and provider wiring that selects it through the `ml-runtime` effective-backend seam. The bicubic `CpuImageUpscaler` remains the universal floor.

### Modified Capabilities
<!-- None. The `ortCpu` probe plugs into ml-runtime's already-injectable EP-probe seam without changing its requirements; ai-image-upscaler's CpuImageUpscaler + manga UI are unchanged. -->

## Impact

- **Dependency**: `onnxruntime: ^1.4.1` is already present in `app/pubspec.yaml:1` (added by the merged build-viability spike, PR #11) with native plugin lists updated for Linux/Windows/iOS and the Android `compileSdk` override in `app/android/build.gradle.kts:34`. No new dependency is introduced here.
- **New code** under `app/lib/core/ml/`: `onnx_image_upscaler.dart` (the upscaler) and an `ort_capability_probe.dart` (concrete `ortCpu` probe), wired in `app/lib/core/ml/providers.dart:1`.
- **Provider seam**: `imageUpscalerProvider` in `app/lib/core/ml/providers.dart` gains a model-present + probe-available branch; default resolution (bicubic floor) is preserved for the shipped experimental-OFF path.
- **Tests/assets**: a tiny `.onnx` fixture under `app/test/fixtures/ml/` (or `app/assets/`) and a new `app/test/core/ml/onnx_image_upscaler_test.dart` smoke test; `flutter test` must pass locally on macOS and in CI.
- **No UI change**: the manga viewer upscale action (`ai-image-upscaler`) keeps using `imageUpscalerProvider` and transparently benefits when the ORT path becomes effective.

## Non-goals

- **No GPU execution providers** (CoreML / NNAPI / DirectML). Those are step 4 (`enable-gpu-execution-providers`). This change is CPU EP only.
- **No model distribution** (download from GitHub Releases, SHA-256 verification, on-disk cache, model-management settings UI). That is step 3 (`add-upscale-model-distribution`). Here the model path is injected by the caller / test.
- **No shipping a real Real-ESRGAN/waifu2x model** in the app; only a tiny synthetic fixture for CI inference smoke. Real model selection/licensing is handled in step 3.
- **No video AI** (Anime4K / RIFE / offline Real-ESRGAN export) — explicitly out of the `ImageUpscaler` seam per ADR-0007 §6.
- **No change to the experimental default**: AI upscaling stays default-OFF; this change does not enable it for end users.
