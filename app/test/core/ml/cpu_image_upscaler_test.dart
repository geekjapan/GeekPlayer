import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:geekplayer/core/ml/cpu_image_upscaler.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/upscale_request.dart';

/// Encodes a solid-color 4x4 PNG for use as test input.
Uint8List _makePng(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(128, 64, 32));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('CpuImageUpscaler', () {
    const CpuImageUpscaler upscaler = CpuImageUpscaler();

    test('2x upscale returns doubled dimensions', () async {
      final Uint8List png = _makePng(4, 4);
      final result = await upscaler.upscale(
        UpscaleRequest(bytes: png, srcWidth: 4, srcHeight: 4, scaleFactor: 2),
      );

      expect(result.outWidth, 8);
      expect(result.outHeight, 8);
      expect(result.backend, MlBackend.bicubicCpu);
      // Real interpolation: output bytes should be non-null and non-empty.
      expect(result.bytes, isNotEmpty);
    });

    test('1x upscale returns same dimensions', () async {
      final Uint8List png = _makePng(8, 6);
      final result = await upscaler.upscale(
        UpscaleRequest(bytes: png, srcWidth: 8, srcHeight: 6, scaleFactor: 1),
      );

      expect(result.outWidth, 8);
      expect(result.outHeight, 6);
      expect(result.backend, MlBackend.bicubicCpu);
      expect(result.bytes, isNotEmpty);
    });

    test('3x upscale scales width and height by 3', () async {
      final Uint8List png = _makePng(10, 5);
      final result = await upscaler.upscale(
        UpscaleRequest(bytes: png, srcWidth: 10, srcHeight: 5, scaleFactor: 3),
      );

      expect(result.outWidth, 30);
      expect(result.outHeight, 15);
      expect(result.backend, MlBackend.bicubicCpu);
    });

    test('output bytes differ from input bytes for 2x upscale', () async {
      // Verifies real interpolation is happening (not passthrough).
      final Uint8List png = _makePng(4, 4);
      final result = await upscaler.upscale(
        UpscaleRequest(bytes: png, srcWidth: 4, srcHeight: 4, scaleFactor: 2),
      );

      // The output should be a different (larger) image.
      expect(result.bytes.length, isNot(equals(png.length)));
    });
  });
}
