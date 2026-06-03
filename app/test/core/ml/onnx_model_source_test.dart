import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/onnx_model_source.dart';

void main() {
  group('OnnxModelSource', () {
    test('file source exposes its path and equals by path', () {
      const a = OnnxModelSource.file('/models/x.onnx');
      const b = OnnxModelSource.file('/models/x.onnx');
      const c = OnnxModelSource.file('/models/y.onnx');
      expect(a, isA<OnnxModelFileSource>());
      expect((a as OnnxModelFileSource).path, '/models/x.onnx');
      expect(a.file.path, '/models/x.onnx');
      expect(a, b);
      expect(a, isNot(c));
    });

    test('bytes source equals by identical bytes instance', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final a = OnnxModelSource.bytes(bytes);
      final b = OnnxModelSource.bytes(bytes);
      expect(a, isA<OnnxModelBytesSource>());
      expect((a as OnnxModelBytesSource).bytes, same(bytes));
      expect(a, b);
    });
  });
}
