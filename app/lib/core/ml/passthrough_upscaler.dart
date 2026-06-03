import 'ml_backend.dart';
import 'image_upscaler.dart';
import 'upscale_request.dart';
import 'upscale_result.dart';

/// Pure-Dart CPU upscaler that returns the input bytes unchanged.
///
/// This is the default [ImageUpscaler] used until platform-native
/// backends (CoreML, NNAPI, etc.) are implemented. The output dimensions
/// are set to `srcWidth * scaleFactor` × `srcHeight * scaleFactor` but
/// no actual pixel interpolation occurs.
class PassthroughUpscaler implements ImageUpscaler {
  const PassthroughUpscaler();

  @override
  Future<UpscaleResult> upscale(UpscaleRequest request) async {
    // Passthrough always reports cpu — no hardware acceleration is used.
    return UpscaleResult(
      bytes: request.bytes,
      outWidth: request.srcWidth * request.scaleFactor,
      outHeight: request.srcHeight * request.scaleFactor,
      backend: MlBackend.cpu,
    );
  }
}
