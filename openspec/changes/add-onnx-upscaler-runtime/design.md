## Context

ADR-0007 selects ONNX Runtime (ORT) as the single inference bridge for AI image upscaling, with the **CPU execution provider** as the everywhere-verifiable tier above the bicubic floor. Step 1 (`refactor-ml-runtime-effective-backend`, merged) landed the seam: `MlRuntime.probe()` resolves an effective `MlBackend` through `preferred EP → ortCpu → bicubicCpu`, gated by an experimental flag and model state, with all inputs injectable (`ExecutionProviderProbe`, `ModelStateResolver`, `ExperimentalFlagResolver`). The defaults are floor-only: `_noExecutionProviders` (always false), `_modelAbsent`, `_experimentalOff`. The `onnxruntime: ^1.4.1` package and its native build for 5/6 platforms landed in the merged spike (PR #11); the Android `compileSdk` override is committed but CI-unverified (billing block).

What is missing: nothing actually runs ONNX. `ortCpu` can be named but never executes. This change adds the first real inference path.

The ORT Dart API (`onnxruntime 1.4.1`): `OrtEnv.instance.init()/release()` (process-global), `OrtSessionOptions()..appendCPUProvider(CPUFlags.useArena)..setIntraOpNumThreads(n)`, `OrtSession.fromBuffer(Uint8List, opts)` / `.fromFile(File, opts)`, `OrtValueTensor.createTensorWithDataList(Float32List, [shape])`, `session.run(OrtRunOptions(), {name: tensor}, [outputNames]) -> List<OrtValue?>`, `runAsync(...)` (isolate), and `release()` on session/value/options.

## Goals / Non-Goals

**Goals:**
- A working `OnnxImageUpscaler` (`ImageUpscaler`) running an injected ONNX model on the ORT CPU EP, reporting `MlBackend.ortCpu`.
- A concrete `ortCpu` availability probe behind `MlRuntime`'s injectable EP-probe seam.
- A pure `resolveImageUpscaler` selection function (unit-testable) for the eventual async wiring.
- A committed tiny ONNX fixture + a real CPU-EP inference smoke test, runnable locally on macOS and in CI.

**Non-Goals:**
- GPU EPs (CoreML/NNAPI/DirectML) — step 4.
- Model download / verification / cache / settings UI — step 3.
- Making `imageUpscalerProvider` async or migrating the manga viewer — deferred to step 3 (no user-facing model exists yet, experimental is default-OFF, so the provider always resolves to the floor in this change).
- Shipping a real Real-ESRGAN/waifu2x model.
- Video AI.

## Decisions

### D1: CPU EP only, ORT env as a process-global singleton
`OnnxImageUpscaler` builds `OrtSessionOptions` with `appendCPUProvider(CPUFlags.useArena)` and `setIntraOpNumThreads(1)` (deterministic, CI-friendly). `OrtEnv.instance.init()` is idempotent and process-global; the upscaler ensures it is initialized but never releases it (other upscalers/probes share it). Only the per-upscaler `OrtSession` is owned and released. *Alternative:* per-instance env — rejected; the package models env as a singleton and double-release risks native crashes.

### D2: Model is an injected source, not sourced here
Introduce a small `OnnxModelSource` abstraction with two forms — a file path and in-memory `Uint8List` bytes — mapping to `OrtSession.fromFile`/`fromBuffer`. The caller (tests now; `ModelRepository` in step 3) supplies it. The upscaler performs zero network/cache access. *Alternative:* upscaler downloads its own model — rejected; that is step 3's capability and would couple inference to distribution.

### D3: Image ↔ tensor contract (NCHW float32 RGB, [0,1])
Preprocess with the `image` package: decode → ensure RGB → build a `Float32List` in NCHW layout `[1,3,H,W]` normalized to `[0,1]`. Input tensor via `OrtValueTensor.createTensorWithDataList(data, [1,3,H,W])`. Run, read output `OrtValueTensor` shape `[1,3,outH,outW]`, denormalize to 8-bit, repack to an `Image`, encode PNG. The **scale factor is read from the output shape** (`outH / H`), not assumed, so the same code works for any integer-scale SR model. Input/output names come from the session's input/output metadata (first input, first output). *Alternative:* NHWC or [0,255] — rejected; NCHW float[0,1] RGB is the dominant Real-ESRGAN/waifu2x ONNX convention, so the fixture and future real models share one contract.

### D4: Synchronous inference in this step; isolate offload deferred
Use synchronous `session.run` inside the `async upscale()`. For large images this blocks the platform thread, but: the feature is experimental/default-OFF, the manga viewer already shows a progress indicator, and the test images are tiny. Moving to `runAsync`/`OrtIsolateSession` (true background inference) is a follow-up tracked as a risk. *Alternative:* isolate from day one — rejected for step 2; `OrtIsolateSession` adds setup/marshalling complexity not needed to prove the integration.

### D5: Test fixture = committed tiny Resize ONNX model
Generate, once at dev time, a minimal NCHW RGB ONNX model whose single `Resize` node (mode `nearest`, `scales` initializer `[1,1,2,2]`, opset 13) upscales `[1,3,H,W] → [1,3,2H,2W]`. Commit both the generator (`tool/ml/gen_test_upscaler_onnx.py`, using `onnx.helper`) **and** the resulting binary fixture (`app/test/fixtures/ml/upscale_x2_nearest.onnx`, a few hundred bytes). Tests load the committed binary — **no Python at test time**. The model is a black-box stand-in that exercises the full decode→tensor→ORT→tensor→encode plumbing deterministically. *Alternative:* hand-serialize ONNX protobuf in Dart — rejected as fragile; a real (large) SR model — rejected, that is step 3 and too big for CI.

### D6: `ortCpu` probe = can ORT initialize?
`ortCpu_probe` attempts `OrtEnv.instance.init()` and reads `OrtEnv.version`; success → available, any throw → unavailable (never rethrows). It answers only "does the ORT native runtime load and initialize on this platform" — sufficient for the CPU EP, which ORT always provides when loaded. It is wired as an `ExecutionProviderProbe` that returns `true` for `MlBackend.ortCpu` (and, for now, `false` for GPU EPs — step 4 extends it). *Alternative:* create a throwaway session to test — rejected as needlessly heavy for an availability check.

### D7: Pure selection seam, providers keep the sync floor
`resolveImageUpscaler({required MlBackend effective, OnnxModelSource? model})` returns `OnnxImageUpscaler(model)` iff `effective == ortCpu && model != null`, else `const CpuImageUpscaler()`. It is pure and fully unit-tested. `imageUpscalerProvider` is **unchanged** (sync, returns the floor) because experimental is default-OFF and no model is sourced in this step — the provider would always pick the floor anyway. Step 3 makes the provider async (probe + `ModelRepository`) and migrates `manga_viewer_screen.dart:161`. This keeps step 2 non-breaking and keeps the `ai-image-upscaler` / `ml-runtime` provider contracts intact.

## Risks / Trade-offs

- **Android CPU-EP inference is CI-unverified** (GitHub Actions billing block; no local Android SDK). → Mitigation: the smoke test verifies the path **locally on macOS** now; Android verification happens when CI billing is restored. The `checkDebugAarMetadata`/compileSdk fix must pass before trusting Android.
- **Synchronous `run` blocks the UI thread** for large images. → Mitigation: experimental/default-OFF + progress indicator; isolate offload is a tracked follow-up before the feature graduates.
- **Fixture generation needs `onnx` (pip) at dev time.** → Mitigation: commit the binary fixture so the build/test path never needs Python; the generator script is for reproducibility only.
- **Float/opset numeric differences across platforms.** → Mitigation: the fixture uses integer-scale nearest `Resize` (bit-stable, no interpolation), so the smoke assertion is dimensional + decodable rather than pixel-exact; real-model numeric tolerance is a step 3/4 concern.
- **Native handle leaks** if sessions aren't released. → Mitigation: explicit `dispose()` releasing the session; env left to the singleton; a test asserts repeated construct/dispose is safe.

## Migration Plan

Additive only. New files under `app/lib/core/ml/` (`onnx_image_upscaler.dart`, `onnx_model_source.dart`, `ort_capability_probe.dart`, `upscaler_selection.dart`) plus the test + fixture + generator. No existing file's behavior changes except (optionally) re-exporting the new symbols. Rollback = revert the change; the floor and all step-1 behavior remain. No data/schema/locale changes.

## Open Questions

- Should `OrtEnv` be initialized eagerly at app start or lazily on first probe/inference? Leaning lazy (on first use) to avoid native init cost when the feature is OFF; revisit in step 3 when the provider goes async.
- Exact input/output tensor names: read from session metadata at runtime (robust) vs. assume conventional names. Decision: read from metadata; fixture will still use conventional `input`/`output` names for clarity.
