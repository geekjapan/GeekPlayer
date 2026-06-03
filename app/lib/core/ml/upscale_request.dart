import 'package:flutter/foundation.dart';

/// Input to an upscaling operation.
@immutable
class UpscaleRequest {
  const UpscaleRequest({
    required this.bytes,
    required this.srcWidth,
    required this.srcHeight,
    required this.scaleFactor,
  }) : assert(scaleFactor >= 1, 'scaleFactor must be >= 1');

  /// Raw encoded image bytes (e.g., PNG or JPEG).
  final Uint8List bytes;

  /// Width of the source image in pixels.
  final int srcWidth;

  /// Height of the source image in pixels.
  final int srcHeight;

  /// Integer scale multiplier (e.g., 2 for 2× upscaling).
  final int scaleFactor;
}
