import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import 'image_upscaler.dart';
import 'ml_backend.dart';
import 'onnx_model_source.dart';
import 'upscale_request.dart';
import 'upscale_result.dart';

/// Thrown when ONNX upscaling fails (bad model, decode, or inference error).
///
/// It is always catchable so the `ml-runtime` selection seam can fall back to
/// the bicubic CPU floor rather than crashing the process (ADR-0007).
class OnnxUpscaleException implements Exception {
  const OnnxUpscaleException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'OnnxUpscaleException: $message'
      : 'OnnxUpscaleException: $message ($cause)';
}

/// An [ImageUpscaler] that runs an injected ONNX super-resolution model on the
/// ONNX Runtime **CPU execution provider** (ADR-0007 step 2).
///
/// Image ↔ tensor contract: NCHW `float32` RGB normalized to `[0, 1]`
/// (`[1, 3, H, W]` in, `[1, 3, outH, outW]` out). The scale factor is read
/// from the output shape, so any integer-scale model works. The model is
/// *injected* via [OnnxModelSource]; this class never sources models itself.
///
/// Inference runs synchronously on the calling isolate in this step; moving to
/// a background isolate ([OrtIsolateSession]) is a tracked follow-up.
class OnnxImageUpscaler implements ImageUpscaler {
  OnnxImageUpscaler(this.modelSource);

  final OnnxModelSource modelSource;

  OrtSession? _session;
  bool _disposed = false;

  OrtSession _ensureSession() {
    if (_disposed) {
      throw const OnnxUpscaleException('upscaler has been disposed');
    }
    final OrtSession? existing = _session;
    if (existing != null) return existing;
    try {
      OrtEnv.instance.init();
      final OrtSessionOptions options = OrtSessionOptions()
        ..setIntraOpNumThreads(1)
        ..setInterOpNumThreads(1)
        ..appendCPUProvider(CPUFlags.useArena);
      final OrtSession created = switch (modelSource) {
        OnnxModelFileSource(:final file) => OrtSession.fromFile(file, options),
        OnnxModelBytesSource(:final bytes) => OrtSession.fromBuffer(
          bytes,
          options,
        ),
      };
      options.release();
      _session = created;
      return created;
    } catch (e) {
      throw OnnxUpscaleException('failed to load ONNX model', e);
    }
  }

  @override
  Future<UpscaleResult> upscale(UpscaleRequest request) async {
    final OrtSession session = _ensureSession();

    final img.Image? decoded = img.decodeImage(request.bytes);
    if (decoded == null) {
      throw const OnnxUpscaleException('failed to decode input image');
    }

    final OrtValueTensor input = _toInputTensor(decoded);
    final OrtRunOptions runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      final String inputName = session.inputNames.first;
      final String outputName = session.outputNames.first;
      outputs = session.run(runOptions, {inputName: input}, [outputName]);
      final OrtValue? out = outputs.first;
      if (out == null) {
        throw const OnnxUpscaleException('model produced no output tensor');
      }
      final Uint8List bytes = _fromOutputTensor(out);
      final img.Image upscaled = img.decodeImage(bytes)!;
      return UpscaleResult(
        bytes: bytes,
        outWidth: upscaled.width,
        outHeight: upscaled.height,
        backend: MlBackend.ortCpu,
      );
    } on OnnxUpscaleException {
      rethrow;
    } catch (e) {
      throw OnnxUpscaleException('inference failed', e);
    } finally {
      input.release();
      runOptions.release();
      outputs?.forEach((o) => o?.release());
    }
  }

  /// Decode → NCHW `float32` RGB in `[0, 1]`, shape `[1, 3, H, W]`.
  OrtValueTensor _toInputTensor(img.Image image) {
    final int w = image.width;
    final int h = image.height;
    final int plane = h * w;
    final Float32List data = Float32List(3 * plane);
    for (int y = 0; y < h; y++) {
      final int rowOffset = y * w;
      for (int x = 0; x < w; x++) {
        final img.Pixel p = image.getPixel(x, y);
        final int i = rowOffset + x;
        data[i] = p.rNormalized.toDouble();
        data[plane + i] = p.gNormalized.toDouble();
        data[2 * plane + i] = p.bNormalized.toDouble();
      }
    }
    return OrtValueTensor.createTensorWithDataList(data, [1, 3, h, w]);
  }

  /// `[1, 3, outH, outW]` float in `[0, 1]` → encoded PNG bytes.
  Uint8List _fromOutputTensor(OrtValue out) {
    final Object? value = out.value;
    if (value is! List<dynamic> || value.isEmpty) {
      throw const OnnxUpscaleException('unexpected output tensor shape');
    }
    final List<dynamic> batch = value.first as List<dynamic>; // [3, outH, outW]
    if (batch.length < 3) {
      throw const OnnxUpscaleException('output tensor is not 3-channel');
    }
    final List<dynamic> rPlane = batch[0] as List<dynamic>;
    final List<dynamic> gPlane = batch[1] as List<dynamic>;
    final List<dynamic> bPlane = batch[2] as List<dynamic>;
    final int outH = rPlane.length;
    final int outW = (rPlane.first as List<dynamic>).length;

    final img.Image result = img.Image(width: outW, height: outH);
    for (int y = 0; y < outH; y++) {
      final List<dynamic> rRow = rPlane[y] as List<dynamic>;
      final List<dynamic> gRow = gPlane[y] as List<dynamic>;
      final List<dynamic> bRow = bPlane[y] as List<dynamic>;
      for (int x = 0; x < outW; x++) {
        result.setPixelRgb(
          x,
          y,
          _to8bit(rRow[x] as num),
          _to8bit(gRow[x] as num),
          _to8bit(bRow[x] as num),
        );
      }
    }
    return Uint8List.fromList(img.encodePng(result));
  }

  static int _to8bit(num normalized) =>
      (normalized * 255.0).round().clamp(0, 255);

  /// Releases the ORT session. Idempotent; the shared [OrtEnv] singleton is
  /// left intact for other upscalers/probes.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session?.release();
    _session = null;
  }
}
