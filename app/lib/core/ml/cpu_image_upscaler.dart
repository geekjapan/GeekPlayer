import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'image_upscaler.dart';
import 'ml_backend.dart';
import 'upscale_request.dart';
import 'upscale_result.dart';

/// Pure-Dart CPU upscaler using bicubic interpolation.
///
/// Uses the `image` package to decode the input bytes, resize using cubic
/// interpolation at [UpscaleRequest.scaleFactor], and re-encode to PNG.
/// All computation runs on the calling isolate (or via [compute] from the UI
/// layer to keep the main thread responsive).
class CpuImageUpscaler implements ImageUpscaler {
  const CpuImageUpscaler();

  @override
  Future<UpscaleResult> upscale(UpscaleRequest request) async {
    final Uint8List output = await compute(_upscaleInIsolate, request);
    return UpscaleResult(
      bytes: output,
      outWidth: request.srcWidth * request.scaleFactor,
      outHeight: request.srcHeight * request.scaleFactor,
      backend: MlBackend.bicubicCpu,
    );
  }
}

Uint8List _upscaleInIsolate(UpscaleRequest request) {
  final img.Image? source = img.decodeImage(request.bytes);
  if (source == null) {
    throw StateError(
      'CpuImageUpscaler: failed to decode image '
      '(${request.srcWidth}x${request.srcHeight})',
    );
  }
  final img.Image resized = img.copyResize(
    source,
    width: request.srcWidth * request.scaleFactor,
    height: request.srcHeight * request.scaleFactor,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodePng(resized));
}
