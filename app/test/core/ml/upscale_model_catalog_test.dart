import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/upscale_model_catalog.dart';

void main() {
  group('UpscaleModelEntry.modelScale / downscaleFactor', () {
    test('modelScale defaults to scale (no downscale)', () {
      const e = UpscaleModelEntry(
        modelId: 'm',
        version: 'v',
        url: 'https://example.invalid/m.onnx',
        sha256: 'x',
        scale: 4,
        license: 'BSD-3-Clause',
      );
      expect(e.modelScale, 4);
      expect(e.downscaleFactor, 1);
    });

    test('modelScale > scale yields downscaleFactor', () {
      const e = UpscaleModelEntry(
        modelId: 'm',
        version: 'v',
        url: 'https://example.invalid/m.onnx',
        sha256: 'x',
        scale: 2,
        modelScale: 4,
        license: 'BSD-3-Clause',
      );
      expect(e.downscaleFactor, 2);
    });
  });

  group('production catalog (real Real-ESRGAN x4, 2x via downscale)', () {
    test('both slots are the same permissive, fixed-shape real model', () {
      for (final e in UpscaleModelCatalog.all) {
        expect(e.modelId, 'realesrgan-x4plus-anime-6b');
        expect(e.license, 'BSD-3-Clause'); // permissive, not a fixture
        expect(e.modelScale, 4); // native 4x model
        expect(e.tileSize, 256); // fixed-shape tile
        expect(e.url, startsWith('https://'));
        expect(e.sha256.length, 64);
      }
    });

    test('x2 downscales the 4x model; x4 runs native', () {
      expect(UpscaleModelCatalog.x2.scale, 2);
      expect(UpscaleModelCatalog.x2.downscaleFactor, 2);
      expect(UpscaleModelCatalog.x4.scale, 4);
      expect(UpscaleModelCatalog.x4.downscaleFactor, 1);
    });

    test('forScale selects by target scale', () {
      expect(UpscaleModelCatalog.forScale(2), UpscaleModelCatalog.x2);
      expect(UpscaleModelCatalog.forScale(4), UpscaleModelCatalog.x4);
      expect(UpscaleModelCatalog.forScale(3), isNull);
    });

    test('no fixture model is a permanent catalog entry', () {
      for (final e in UpscaleModelCatalog.all) {
        expect(e.modelId.contains('fixture'), isFalse);
      }
    });
  });
}
