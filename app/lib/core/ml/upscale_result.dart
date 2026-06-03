import 'package:flutter/foundation.dart';

import 'ml_backend.dart';

/// Output of an upscaling operation.
@immutable
class UpscaleResult {
  const UpscaleResult({
    required this.bytes,
    required this.outWidth,
    required this.outHeight,
    required this.backend,
  });

  /// Raw encoded image bytes of the upscaled image.
  final Uint8List bytes;

  /// Width of the upscaled image in pixels.
  final int outWidth;

  /// Height of the upscaled image in pixels.
  final int outHeight;

  /// The backend that produced this result.
  final MlBackend backend;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpscaleResult &&
          runtimeType == other.runtimeType &&
          bytes == other.bytes &&
          outWidth == other.outWidth &&
          outHeight == other.outHeight &&
          backend == other.backend;

  @override
  int get hashCode => Object.hash(bytes, outWidth, outHeight, backend);

  @override
  String toString() =>
      'UpscaleResult(outWidth: $outWidth, outHeight: $outHeight, backend: $backend)';
}
