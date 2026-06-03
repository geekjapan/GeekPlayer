import 'upscale_request.dart';
import 'upscale_result.dart';

/// Abstract contract for AI-driven image upscaling.
///
/// Concrete implementations delegate to platform-specific backends
/// (CoreML, NNAPI, ONNX Runtime, TensorRT) or to the pure-Dart
/// [PassthroughUpscaler] default.
abstract interface class ImageUpscaler {
  /// Upscales [request] and returns the result.
  Future<UpscaleResult> upscale(UpscaleRequest request);
}
