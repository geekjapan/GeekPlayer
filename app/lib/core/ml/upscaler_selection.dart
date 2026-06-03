import 'cpu_image_upscaler.dart';
import 'image_upscaler.dart';
import 'ml_backend.dart';
import 'onnx_image_upscaler.dart';
import 'onnx_model_source.dart';

/// Pure selection seam mapping an effective [MlBackend] (+ optional model) to a
/// concrete [ImageUpscaler] (ADR-0007 step 2).
///
/// Returns an [OnnxImageUpscaler] only when the effective backend is
/// [MlBackend.ortCpu] **and** a model source is present; otherwise the bicubic
/// [CpuImageUpscaler] floor. The async, probe-driven `imageUpscalerProvider`
/// wiring (and the manga-viewer migration) is deferred to the
/// model-distribution change, which is the first point a real model exists.
ImageUpscaler resolveImageUpscaler({
  required MlBackend effective,
  OnnxModelSource? model,
}) {
  if (effective == MlBackend.ortCpu && model != null) {
    return OnnxImageUpscaler(model);
  }
  return const CpuImageUpscaler();
}
