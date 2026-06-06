## MODIFIED Requirements

### Requirement: Riverpod providers for the ML runtime

The system SHALL expose Riverpod providers `mlRuntimeProvider` and `imageUpscalerProvider`, both `keepAlive: true`, wired via `@Riverpod` codegen and overridable in tests. In production, `mlRuntimeProvider` SHALL construct its `MlRuntime` with the real injected resolvers rather than the floor defaults: the `ExperimentalFlagResolver` reads the AI-upscaling enable toggle, the `ModelStateResolver` reads the selected model's presence from the `ModelRepository`, and the `ExecutionProviderProbe` is the ONNX Runtime CPU probe (`ortCpuExecutionProviderProbe`). `imageUpscalerProvider` MUST remain overridable in tests; its concrete selection semantics (async resolution from `MlRuntime.probe()` and the model source) are owned by the `ai-image-upscaler` capability.

#### Scenario: imageUpscalerProvider is overridable

- **WHEN** a test overrides `imageUpscalerProvider` with a fake `ImageUpscaler`
- **THEN** a consumer reading the provider observes the fake instance

#### Scenario: Production mlRuntimeProvider injects real resolvers

- **WHEN** `mlRuntimeProvider` is read in production wiring (no overrides)
- **THEN** the constructed `MlRuntime` uses the experimental-flag, model-state, and ORT CPU probe resolvers — so `probe()` reflects the actual toggle and model presence rather than the always-floor defaults
