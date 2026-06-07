import 'package:flutter/foundation.dart';

import '../../features/settings/domain/ai_upscale_backend_override.dart';
import 'cpu_image_upscaler.dart';
import 'image_upscaler.dart';
import 'ml_backend.dart';
import 'onnx_image_upscaler.dart';
import 'onnx_model_source.dart';

/// Pure selection seam mapping an effective [MlBackend] (+ optional model) to a
/// concrete [ImageUpscaler] (ADR-0007 step 2 / step 4).
///
/// Returns an [OnnxImageUpscaler] when the effective backend is an ONNX Runtime
/// EP — [MlBackend.ortCpu], [MlBackend.coremlEp], or [MlBackend.nnapiEp] — and a
/// model source is present, passing the effective backend as the upscaler's
/// target EP. Otherwise the bicubic [CpuImageUpscaler] floor.
ImageUpscaler resolveImageUpscaler({
  required MlBackend effective,
  OnnxModelSource? model,
  int? tileSize,
}) {
  if (model != null && _isOnnxBackend(effective)) {
    return OnnxImageUpscaler(
      model,
      targetBackend: effective,
      tileSize: tileSize,
    );
  }
  return const CpuImageUpscaler();
}

/// Whether [backend] is served by the ONNX Runtime upscaler (CPU or GPU EP).
bool _isOnnxBackend(MlBackend backend) =>
    backend == MlBackend.ortCpu ||
    backend == MlBackend.coremlEp ||
    backend == MlBackend.nnapiEp;

/// Maps an advanced backend [override] (+ current [platform]) to a forced
/// preferred [MlBackend], or null for "auto" (use the platform default).
///
/// `forceCpu` always pins ONNX Runtime's CPU EP. `forceGpu` resolves to a GPU EP
/// the current `onnxruntime` package can actually append (iOS/macOS → CoreML,
/// Android → NNAPI). On platforms with no usable GPU EP it pins `ortCpu`
/// (Windows — DirectML is not exposed by the package; ADR-0007 amendment) or
/// returns null (Linux/other) so the normal chain applies. The result is still
/// validated by `MlRuntime.probe()` and degrades to the bicubic floor when the
/// chosen backend is unavailable.
///
/// Windows returns `ortCpu` rather than `directmlEp` so `forceGpu` never selects
/// an EP that can never be available today; revisit if/when a future ORT package
/// exposes DirectML.
MlBackend? resolvePreferredOverride(
  AiUpscaleBackendOverride override,
  TargetPlatform platform,
) {
  switch (override) {
    case AiUpscaleBackendOverride.auto:
      return null;
    case AiUpscaleBackendOverride.forceCpu:
      return MlBackend.ortCpu;
    case AiUpscaleBackendOverride.forceGpu:
      switch (platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          return MlBackend.coremlEp;
        case TargetPlatform.android:
          return MlBackend.nnapiEp;
        case TargetPlatform.windows:
          return MlBackend.ortCpu;
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return null;
      }
  }
}
