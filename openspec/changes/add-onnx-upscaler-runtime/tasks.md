## 1. Test fixture (tiny ONNX upscaling model)

- [x] 1.1 Add `tool/ml/gen_test_upscaler_onnx.py` that builds a minimal NCHW RGB model — single `Resize` node (mode `nearest`, `scales` initializer `[1,1,2,2]`, opset 13), input `input [1,3,H,W]`, output `output [1,3,2H,2W]` — via `onnx.helper`, and writes the `.onnx` bytes.
- [x] 1.2 Run the generator (dev-only `pip install onnx`) and commit the resulting fixture at `app/test/fixtures/ml/upscale_x2_nearest.onnx`; verify it loads in an `OrtSession`.
- [x] 1.3 Document in the script header that the fixture is committed and Python is **not** needed at test time.

## 2. Model source + image↔tensor preprocessing

- [x] 2.1 Add `app/lib/core/ml/onnx_model_source.dart`: an `OnnxModelSource` with `OnnxModelSource.file(String path)` and `OnnxModelSource.bytes(Uint8List)` forms.
- [x] 2.2 Add preprocessing in `onnx_image_upscaler.dart`: decode input bytes (`image` pkg) → RGB → `Float32List` NCHW `[1,3,H,W]` normalized `[0,1]`.
- [x] 2.3 Add postprocessing: read output `OrtValueTensor` shape `[1,3,outH,outW]`, denormalize to 8-bit, repack to `Image`, encode PNG; derive scale as `outH / srcHeight`.

## 3. OnnxImageUpscaler (ORT CPU EP)

- [x] 3.1 Implement `OnnxImageUpscaler implements ImageUpscaler` in `app/lib/core/ml/onnx_image_upscaler.dart`: ensure `OrtEnv.instance.init()`, build `OrtSessionOptions..appendCPUProvider(CPUFlags.useArena)..setIntraOpNumThreads(1)`, create session from the `OnnxModelSource` lazily/once.
- [x] 3.2 Implement `upscale()`: read input/output names from session metadata, build input tensor, `session.run(OrtRunOptions(), {name: tensor}, [outName])`, postprocess, return `UpscaleResult(..., backend: MlBackend.ortCpu)`; release per-call `OrtValue`/`OrtRunOptions`.
- [x] 3.3 Implement `dispose()` that releases the `OrtSession` (idempotent; leaves the shared `OrtEnv` singleton intact).
- [x] 3.4 Ensure failures (malformed model, decode/inference error) surface as catchable exceptions, never a process crash.

## 4. ORT CPU availability probe

- [x] 4.1 Add `app/lib/core/ml/ort_capability_probe.dart`: `ortCpuProbe` attempts `OrtEnv.instance.init()` + reads `OrtEnv.version`; returns `true` for `MlBackend.ortCpu` on success, `false` (no throw) otherwise, `false` for GPU EPs (deferred to step 4).
- [x] 4.2 Expose it as an `ExecutionProviderProbe` compatible with `MlRuntime`'s injectable seam.

## 5. Pure selection seam

- [x] 5.1 Add `app/lib/core/ml/upscaler_selection.dart`: `resolveImageUpscaler({required MlBackend effective, OnnxModelSource? model})` returning `OnnxImageUpscaler` iff `effective == ortCpu && model != null`, else `const CpuImageUpscaler()`.
- [x] 5.2 Confirm `imageUpscalerProvider` in `providers.dart` is unchanged (still the sync `CpuImageUpscaler` floor); add a doc comment pointing to step 3 for async wiring.

## 6. Tests (local macOS + CI)

- [x] 6.1 `app/test/core/ml/onnx_image_upscaler_test.dart`: load the fixture, upscale a known-size generated input image, assert output decodes to `2×` dimensions and `backend == MlBackend.ortCpu` (CPU-EP smoke).
- [x] 6.2 Add a test that a malformed-model `OnnxImageUpscaler` throws a catchable exception (no crash), and that construct→dispose→dispose is safe.
- [x] 6.3 `app/test/core/ml/upscaler_selection_test.dart`: cover the floor case, the `ortCpu`+model case → `OnnxImageUpscaler`, and `ortCpu` without model → floor.
- [x] 6.4 `app/test/core/ml/ort_capability_probe_test.dart`: probe reports `ortCpu` available locally and never throws.

## 7. Verify & wire up

- [x] 7.1 Run `dart run build_runner build --delete-conflicting-outputs` if any `@Riverpod` wiring changed (expected: none); otherwise skip.
- [x] 7.2 `fvm flutter analyze` clean; `fvm flutter test test/core/ml/` green locally on macOS.
- [x] 7.3 `openspec validate add-onnx-upscaler-runtime --strict` passes.
- [x] 7.4 Note Android CPU-EP inference remains CI-unverified (billing) and update HANDOFF/PR description accordingly.
