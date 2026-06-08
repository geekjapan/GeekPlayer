import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/onnx_image_upscaler.dart';
import 'package:geekplayer/core/ml/onnx_model_source.dart';
import 'package:geekplayer/core/ml/upscale_request.dart';
import 'package:image/image.dart' as img;

import 'ort_test_support.dart';

/// Real-architecture CPU-EP smoke (add-upscale-model-selection §1.4 / spec
/// onnx-upscaler-runtime "実アーキテクチャ・固定形状の CPU-EP smoke").
///
/// This reduced-architecture fixture shares the real model's op families
/// (Conv / LeakyReLU / PixelShuffle / residual add) at opset 17 and a fixed
/// 64×64 tile, proving those ops load and run on the bundled ONNX Runtime
/// 1.15.1 CPU EP — without shipping ~18 MB of real weights. Per design D8 both
/// the 2x and 4x slots run the Real-ESRGAN RRDBNet model, so this RRDBNet op
/// family is the only one to cover. Generate it with
/// `python tool/export_smoke_fixtures.py --out test/fixtures/ml`; until then
/// this test skips (the fixture is intentionally not a committed binary).
const String _rrdbX4 = 'test/fixtures/ml/smoke_realesrgan_x4_arch.onnx';
const int _tile = 64;

Uint8List _tilePng() {
  final img.Image image = img.Image(width: _tile, height: _tile);
  for (int y = 0; y < _tile; y++) {
    for (int x = 0; x < _tile; x++) {
      image.setPixelRgb(x, y, (x * 3) & 0xFF, (y * 3) & 0xFF, 120);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() async {
  final bool ortReady = await ensureOrtLoadable();

  String? skipFor(String path) {
    if (!ortReady) return 'ONNX Runtime native lib not loadable on test host';
    if (!File(path).existsSync()) {
      return 'fixture missing: $path — run tool/export_smoke_fixtures.py';
    }
    return null;
  }

  group('real-architecture ONNX smoke (ORT 1.15.1 CPU EP)', () {
    test('reduced RRDBNet x4 loads and runs one tile', () async {
      final model = await File(_rrdbX4).readAsBytes();
      final upscaler = OnnxImageUpscaler(OnnxModelSource.bytes(model));
      addTearDown(upscaler.dispose);
      final result = await upscaler.upscale(
        UpscaleRequest(bytes: _tilePng(), srcWidth: _tile, srcHeight: _tile, scaleFactor: 4),
      );
      expect(result.backend, MlBackend.ortCpu);
      expect(result.outWidth, _tile * 4);
      expect(result.outHeight, _tile * 4);
    }, skip: skipFor(_rrdbX4));
  });
}
