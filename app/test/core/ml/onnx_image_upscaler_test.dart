import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/onnx_image_upscaler.dart';
import 'package:geekplayer/core/ml/onnx_model_source.dart';
import 'package:geekplayer/core/ml/upscale_request.dart';
import 'package:image/image.dart' as img;

import 'ort_test_support.dart';

const String _fixturePath = 'test/fixtures/ml/upscale_x2_nearest.onnx';

/// A small RGB test image with distinct per-pixel values, PNG-encoded.
Uint8List _makeInputPng(int w, int h) {
  final img.Image image = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      image.setPixelRgb(x, y, (x * 30) & 0xFF, (y * 50) & 0xFF, 90);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() async {
  final bool ortReady = await ensureOrtLoadable();
  final Object skipReason = ortReady
      ? false
      : 'ONNX Runtime native lib not loadable on test host';

  group('OnnxImageUpscaler (ORT CPU EP)', () {
    test('fixture upscales 2x and reports ortCpu backend', () async {
      final Uint8List model = await File(_fixturePath).readAsBytes();
      final Uint8List input = _makeInputPng(4, 3);
      final upscaler = OnnxImageUpscaler(OnnxModelSource.bytes(model));
      addTearDown(upscaler.dispose);

      final result = await upscaler.upscale(
        UpscaleRequest(bytes: input, srcWidth: 4, srcHeight: 3, scaleFactor: 2),
      );

      expect(result.backend, MlBackend.ortCpu);
      expect(result.outWidth, 8);
      expect(result.outHeight, 6);

      final img.Image out = img.decodeImage(result.bytes)!;
      expect(out.width, 8);
      expect(out.height, 6);

      // Nearest-neighbor x2 (floor, asymmetric): out(x,y) == in(x~/2, y~/2).
      final img.Image src = img.decodeImage(input)!;
      expect(out.getPixel(0, 0).r, src.getPixel(0, 0).r);
      expect(out.getPixel(3, 0).r, src.getPixel(1, 0).r);
      expect(out.getPixel(0, 2).g, src.getPixel(0, 1).g);
    }, skip: skipReason);

    test('malformed model surfaces a catchable exception', () async {
      final upscaler = OnnxImageUpscaler(
        OnnxModelSource.bytes(Uint8List.fromList([0, 1, 2, 3, 4])),
      );
      addTearDown(upscaler.dispose);
      await expectLater(
        upscaler.upscale(
          UpscaleRequest(
            bytes: _makeInputPng(2, 2),
            srcWidth: 2,
            srcHeight: 2,
            scaleFactor: 2,
          ),
        ),
        throwsA(isA<OnnxUpscaleException>()),
      );
    }, skip: skipReason);

    test('construct → dispose → dispose is safe', () async {
      final Uint8List model = await File(_fixturePath).readAsBytes();
      final upscaler = OnnxImageUpscaler(OnnxModelSource.bytes(model));
      // Force session creation via one inference, then double-dispose.
      await upscaler.upscale(
        UpscaleRequest(
          bytes: _makeInputPng(2, 2),
          srcWidth: 2,
          srcHeight: 2,
          scaleFactor: 2,
        ),
      );
      upscaler.dispose();
      expect(upscaler.dispose, returnsNormally);
    }, skip: skipReason);

    test('default target backend reports ortCpu', () async {
      final Uint8List model = await File(_fixturePath).readAsBytes();
      final upscaler = OnnxImageUpscaler(OnnxModelSource.bytes(model));
      addTearDown(upscaler.dispose);
      final result = await upscaler.upscale(
        UpscaleRequest(
          bytes: _makeInputPng(4, 3),
          srcWidth: 4,
          srcHeight: 3,
          scaleFactor: 2,
        ),
      );
      expect(result.backend, MlBackend.ortCpu);
    }, skip: skipReason);

    test(
      'GPU target degrades gracefully and produces correct output',
      () async {
        // Without the CoreML EP the GPU append is caught and the session runs
        // on CPU; with it, CoreML is used. Either way the upscale completes
        // with correct dimensions and never crashes.
        final Uint8List model = await File(_fixturePath).readAsBytes();
        final upscaler = OnnxImageUpscaler(
          OnnxModelSource.bytes(model),
          targetBackend: MlBackend.coremlEp,
        );
        addTearDown(upscaler.dispose);
        final result = await upscaler.upscale(
          UpscaleRequest(
            bytes: _makeInputPng(4, 3),
            srcWidth: 4,
            srcHeight: 3,
            scaleFactor: 2,
          ),
        );
        expect(result.outWidth, 8);
        expect(result.outHeight, 6);
        expect(img.decodeImage(result.bytes)!.width, 8);
        // Effective backend is the requested GPU EP (available) or the ortCpu
        // floor (degraded) — never a crash.
        expect(result.backend, anyOf(MlBackend.coremlEp, MlBackend.ortCpu));
      },
      skip: skipReason,
    );
  });
}
