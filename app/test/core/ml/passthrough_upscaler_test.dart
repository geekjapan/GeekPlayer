import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/ml_backend.dart';
import 'package:geekplayer/core/ml/passthrough_upscaler.dart';
import 'package:geekplayer/core/ml/upscale_request.dart';

void main() {
  const upscaler = PassthroughUpscaler();
  final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);

  group('PassthroughUpscaler', () {
    test('returns input bytes unchanged', () async {
      final request = UpscaleRequest(
        bytes: fakeBytes,
        srcWidth: 100,
        srcHeight: 80,
        scaleFactor: 2,
      );
      final result = await upscaler.upscale(request);
      expect(result.bytes, same(fakeBytes));
    });

    test(
      'output dimensions are srcWidth × scaleFactor and srcHeight × scaleFactor',
      () async {
        final request = UpscaleRequest(
          bytes: fakeBytes,
          srcWidth: 100,
          srcHeight: 80,
          scaleFactor: 2,
        );
        final result = await upscaler.upscale(request);
        expect(result.outWidth, 200);
        expect(result.outHeight, 160);
      },
    );

    test('backend is always cpu', () async {
      final request = UpscaleRequest(
        bytes: fakeBytes,
        srcWidth: 50,
        srcHeight: 50,
        scaleFactor: 4,
      );
      final result = await upscaler.upscale(request);
      expect(result.backend, MlBackend.cpu);
    });

    test('scaleFactor=1 returns same dimensions', () async {
      final request = UpscaleRequest(
        bytes: fakeBytes,
        srcWidth: 640,
        srcHeight: 480,
        scaleFactor: 1,
      );
      final result = await upscaler.upscale(request);
      expect(result.outWidth, 640);
      expect(result.outHeight, 480);
    });
  });
}
