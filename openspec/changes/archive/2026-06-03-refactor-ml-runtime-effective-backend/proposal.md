## Why

ADR-0007 re-organized the AI-upscaling foundation. The current `MlRuntime.describe()` selects a backend purely by platform (iOS → `coreml`, …) even though the only shipped upscaler is `CpuImageUpscaler` (bicubic, CPU). "Selected" is decoupled from "effective", there is no availability probing, no fallback chain, and no experimental gating. This change makes the foundation truthful before any concrete ONNX/GPU backend is built.

## What Changes

- Redefine `MlBackend` to execution-provider-oriented values: `coremlEp`, `nnapiEp`, `directmlEp`, `ortCpu`, `bicubicCpu`.
- Split **preferred** (platform intent) from **effective** (probed) backend. `MlRuntime` gains an async `probe()` returning an expanded `MlCapabilities { preferred, effective, modelState, experimentalEnabled, reason }`.
- Implement the fallback chain (preferred EP → `ortCpu` → `bicubicCpu`) and the experimental/model-state floors (effective is `bicubicCpu` while experimental is OFF or the model is absent).
- Make execution-provider availability, model state, and the experimental flag injectable for testing.
- Update `CpuImageUpscaler` / `PassthroughUpscaler` to report `MlBackend.bicubicCpu`.

This is a code-only foundation refactor; no new dependencies, no UI, no drift changes. AI upscaling remains Experimental and default-OFF (ADR-0007 Decision 0), so user-visible behavior is unchanged (effective stays `bicubicCpu`).

## Impact

- Affected capability: `ml-runtime` (MODIFIED).
- Affected code: `app/lib/core/ml/` (`ml_backend.dart`, `ml_capabilities.dart`, `ml_runtime.dart`, `cpu_image_upscaler.dart`, `passthrough_upscaler.dart`, `providers.dart`) and `app/test/core/ml/`.
- No impact outside `core/ml`: the manga viewer consumes `imageUpscalerProvider`, which still resolves to `CpuImageUpscaler`.
