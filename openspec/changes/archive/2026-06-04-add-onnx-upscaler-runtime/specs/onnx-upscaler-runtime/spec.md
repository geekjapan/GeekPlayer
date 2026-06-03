## ADDED Requirements

### Requirement: ONNX Runtime CPU-EP image upscaler

The system SHALL provide an `OnnxImageUpscaler` that implements the `ImageUpscaler` interface by running an injected ONNX super-resolution model on the ONNX Runtime **CPU execution provider**. It SHALL decode the input bytes, preprocess them into the model's input tensor, run inference, postprocess the output tensor into encoded image bytes, and return an `UpscaleResult` reporting `MlBackend.ortCpu`.

#### Scenario: Upscaler reports the ORT CPU backend

- **WHEN** `OnnxImageUpscaler.upscale` resolves successfully for any request
- **THEN** the returned `UpscaleResult.backend` is `MlBackend.ortCpu`

#### Scenario: Output dimensions reflect the model scale

- **GIVEN** an `OnnxImageUpscaler` backed by a model with scale factor `s`
- **WHEN** `upscale` is called with `srcWidth: w`, `srcHeight: h`
- **THEN** the returned `UpscaleResult` has `outWidth: w * s` and `outHeight: h * s`, and `bytes` decode to an image of those dimensions

### Requirement: Model is injected, not sourced

The `OnnxImageUpscaler` MUST receive its ONNX model as an injected input (a model file path or in-memory bytes) provided by the caller. It MUST NOT download, cache, or otherwise source models itself; model distribution is a separate capability.

#### Scenario: Construction takes an explicit model source

- **WHEN** an `OnnxImageUpscaler` is constructed
- **THEN** it requires an explicit ONNX model source (path or bytes) and performs no network access to obtain a model

### Requirement: Real inference smoke over the CPU execution provider

The capability MUST include a test that loads a small bundled ONNX upscaling model fixture, runs `OnnxImageUpscaler.upscale` end-to-end on the CPU execution provider, and asserts the output is a correctly-sized, decodable image. This test MUST run without a GPU and pass under `flutter test` locally and in every CI job.

#### Scenario: Bundled fixture model produces upscaled output

- **GIVEN** the bundled ONNX upscaling fixture and an input image of known dimensions
- **WHEN** `OnnxImageUpscaler.upscale` runs on the CPU execution provider
- **THEN** it returns an `UpscaleResult` whose bytes decode to an image scaled by the model's factor, with `backend == MlBackend.ortCpu`

### Requirement: ONNX Runtime resource lifecycle

The `OnnxImageUpscaler` MUST manage ONNX Runtime native resources deterministically: the runtime environment and session MUST be initialized before inference and the session MUST be releasable so repeated construction/disposal does not leak native handles.

#### Scenario: Session is released on dispose

- **GIVEN** an `OnnxImageUpscaler` that has created an ORT session
- **WHEN** the upscaler is disposed
- **THEN** the underlying ORT session is released and a subsequent dispose is a safe no-op

### Requirement: Inference failure degrades, never crashes

If the model is malformed, the input cannot be preprocessed, or inference fails, `OnnxImageUpscaler.upscale` MUST surface a catchable error rather than crashing the process, so the `ml-runtime` selection seam can fall back to the bicubic CPU floor.

#### Scenario: Malformed model surfaces a catchable error

- **GIVEN** an `OnnxImageUpscaler` constructed with bytes that are not a valid ONNX model
- **WHEN** `upscale` is invoked
- **THEN** it throws a catchable exception and does not crash the process

### Requirement: Concrete ORT CPU availability probe

The system SHALL provide a concrete `ortCpu` availability probe that reports whether ONNX Runtime can initialize on the current platform. This probe plugs into `MlRuntime`'s existing injectable execution-provider probe seam and replaces step 1's always-false default when wired into production.

#### Scenario: Probe reports ORT availability

- **WHEN** the ORT CPU probe is evaluated on a platform where ONNX Runtime initializes
- **THEN** it reports `ortCpu` as available

#### Scenario: Probe never throws

- **WHEN** the ORT CPU probe is evaluated on a platform where ONNX Runtime cannot initialize
- **THEN** it reports unavailable and does not throw

### Requirement: Pure upscaler-selection seam

The system SHALL provide a pure, synchronous `resolveImageUpscaler` selection function that, given the effective `MlBackend` and a model source, returns an `OnnxImageUpscaler` when the effective backend is `ortCpu` and a model source is present, and the bicubic `CpuImageUpscaler` floor otherwise. The shipped `imageUpscalerProvider` keeps returning the `CpuImageUpscaler` floor in this change (experimental is default-OFF and no model is sourced yet); wiring the async, probe-driven provider and migrating the manga viewer is deferred to the model-distribution change.

#### Scenario: Selection returns the floor for the bicubic backend

- **WHEN** `resolveImageUpscaler` is called with effective backend `bicubicCpu` (or with no model source)
- **THEN** it returns a `CpuImageUpscaler`

#### Scenario: Selection returns the ORT upscaler for ortCpu with a model

- **GIVEN** an effective backend of `ortCpu` and a present model source
- **WHEN** `resolveImageUpscaler` is called
- **THEN** it returns an `OnnxImageUpscaler`

#### Scenario: Shipped provider default is unchanged

- **WHEN** `imageUpscalerProvider` is read with no overrides
- **THEN** the resolved instance is a `CpuImageUpscaler` (this change does not alter the shipped default)
