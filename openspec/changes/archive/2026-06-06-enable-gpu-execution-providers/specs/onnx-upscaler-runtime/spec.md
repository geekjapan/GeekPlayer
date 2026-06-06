## MODIFIED Requirements

### Requirement: ONNX Runtime CPU-EP image upscaler

The system SHALL provide an `OnnxImageUpscaler` that implements the `ImageUpscaler` interface by running an injected ONNX super-resolution model on ONNX Runtime. It SHALL accept a **target `MlBackend`** and append the matching execution provider when creating its session: `coremlEp` → CoreML EP, `nnapiEp` → NNAPI EP, otherwise the CPU EP. The GPU EP MUST be appended **before** the CPU provider so the CPU remains a fallback within the same session. If appending the GPU EP throws, the upscaler MUST catch it and fall back to a CPU-only session rather than failing. It SHALL decode the input bytes, preprocess them into the model's input tensor, run inference, postprocess the output tensor into encoded image bytes, and return an `UpscaleResult` reporting the execution provider actually used.

#### Scenario: Target CPU backend reports the ORT CPU backend

- **GIVEN** an `OnnxImageUpscaler` constructed with target backend `ortCpu`
- **WHEN** `OnnxImageUpscaler.upscale` resolves successfully
- **THEN** the returned `UpscaleResult.backend` is `MlBackend.ortCpu`

#### Scenario: Output dimensions reflect the model scale

- **GIVEN** an `OnnxImageUpscaler` backed by a model with scale factor `s`
- **WHEN** `upscale` is called with `srcWidth: w`, `srcHeight: h`
- **THEN** the returned `UpscaleResult` has `outWidth: w * s` and `outHeight: h * s`, and `bytes` decode to an image of those dimensions

#### Scenario: Unavailable GPU EP degrades to a CPU-only session

- **GIVEN** an `OnnxImageUpscaler` with a GPU target backend on a platform where that EP cannot initialize
- **WHEN** `upscale` runs
- **THEN** appending the GPU EP is caught, inference completes on the CPU provider, and the upscaler does not crash
