import 'package:flutter/foundation.dart';

/// A distributable on-device upscale model in the static catalog (ADR-0007 step 3).
///
/// The catalog is **opt-in metadata only** — model binaries are NOT bundled in
/// the app. Until a follow-up change selects and hosts real Real-ESRGAN /
/// waifu2x ONNX weights (licensing review + GitHub Releases hosting), the
/// shipped entries reference small fixture nearest-neighbor models so the
/// download → SHA-256 verify → cache → runtime-wiring path is exercised
/// end-to-end. AI upscaling is experimental and default-OFF, so no fetch
/// happens unless a user explicitly enables it.
@immutable
class UpscaleModelEntry {
  const UpscaleModelEntry({
    required this.modelId,
    required this.version,
    required this.url,
    required this.sha256,
    required this.scale,
    required this.license,
    this.tileSize,
    int? modelScale,
  }) : modelScale = modelScale ?? scale;

  /// Stable identifier of the model family (kebab-case).
  final String modelId;

  /// Model version. The on-disk cache is keyed by `(modelId, version)`.
  final String version;

  /// HTTPS download URL (GitHub Releases).
  final String url;

  /// Expected lowercase-hex SHA-256 digest of the downloaded bytes.
  final String sha256;

  /// User-facing integer upscale factor (2 or 4).
  final int scale;

  /// The ONNX model's *native* integer scale. When it exceeds [scale], the
  /// upscaler runs the model at its native scale and downscales the result by
  /// [downscaleFactor] — so a single 4x model serves both the 4x and 2x slots
  /// (2x = 4x output bicubic-averaged ×0.5), avoiding a second model/runtime.
  final int modelScale;

  /// SPDX-style license identifier of the model weights.
  final String license;

  /// Fixed model input edge (px) for fixed-shape models that require tiled
  /// inference (real Real-ESRGAN / waifu2x exports). `null` for dynamic-input
  /// models (e.g. the nearest-neighbor fixtures), which are run whole-image.
  /// Must satisfy the scale's divisibility (see [tileSizeSatisfiesScale]).
  final int? tileSize;

  /// Cache-key segment: `<modelId>/<version>`.
  String get cacheKey => '$modelId/$version';

  /// How much to downscale the native model output to reach [scale]
  /// (`modelScale / scale`; 1 when the model is already at the target scale).
  int get downscaleFactor => modelScale ~/ scale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpscaleModelEntry &&
          runtimeType == other.runtimeType &&
          modelId == other.modelId &&
          version == other.version &&
          url == other.url &&
          sha256 == other.sha256 &&
          scale == other.scale &&
          license == other.license &&
          tileSize == other.tileSize &&
          modelScale == other.modelScale;

  @override
  int get hashCode => Object.hash(
    modelId,
    version,
    url,
    sha256,
    scale,
    license,
    tileSize,
    modelScale,
  );

  @override
  String toString() =>
      'UpscaleModelEntry($modelId@$version, x$scale, $license)';
}

/// The static, app-bundled catalog of distributable upscale models (ADR-0007).
///
/// Selection is by scale factor: [forScale] maps the configured 2x/4x to the
/// catalog entry to download and run. Both slots reference the SAME anime-tuned
/// Real-ESRGAN x4 ONNX (RealESRGAN_x4plus_anime_6B, BSD-3-Clause); the 2x slot
/// runs it at its native 4x and downscales ×0.5 ([UpscaleModelEntry.modelScale]
/// / `downscaleFactor`), so a single hosted model serves both — no waifu2x
/// dependency and no fixed-shape offset handling (design D8). The model is
/// exported at opset 17 / IR 9 with a fixed 256px tile (tool/export_real_realesrgan_x4.py)
/// and hosted on a GitHub Release; [sha256] is the digest of that exact file.
class UpscaleModelCatalog {
  const UpscaleModelCatalog._();

  /// Hosting location of the exported Real-ESRGAN x4 ONNX (GitHub Release).
  static const String _x4Url =
      'https://github.com/geekjapan/GeekPlayer/releases/download/models-v1/realesrgan_x4plus_anime_6b_t256.onnx';

  /// SHA-256 of `realesrgan_x4plus_anime_6b_t256.onnx` (opset 17, IR 9, 256px).
  static const String _x4Sha256 =
      '3f224bc597aaf484e387789790d4339053efa7272c01758173b8a1796193c3ee';

  /// 2x slot: the Real-ESRGAN x4 model run natively then downscaled ×0.5.
  static const UpscaleModelEntry x2 = UpscaleModelEntry(
    modelId: 'realesrgan-x4plus-anime-6b',
    version: 'v1-2026.06',
    url: _x4Url,
    sha256: _x4Sha256,
    scale: 2,
    modelScale: 4,
    tileSize: 256,
    license: 'BSD-3-Clause',
  );

  /// 4x slot: the Real-ESRGAN x4 model at its native scale.
  static const UpscaleModelEntry x4 = UpscaleModelEntry(
    modelId: 'realesrgan-x4plus-anime-6b',
    version: 'v1-2026.06',
    url: _x4Url,
    sha256: _x4Sha256,
    scale: 4,
    modelScale: 4,
    tileSize: 256,
    license: 'BSD-3-Clause',
  );

  /// All catalog entries.
  static const List<UpscaleModelEntry> all = <UpscaleModelEntry>[x2, x4];

  /// Supported upscale scale factors, in ascending order.
  static const List<int> supportedScales = <int>[2, 4];

  /// The default scale factor (matches the legacy fixed-2x manga behaviour).
  static const int defaultScale = 2;

  /// The catalog entry for [scale], or `null` if no entry matches.
  static UpscaleModelEntry? forScale(int scale) {
    for (final UpscaleModelEntry entry in all) {
      if (entry.scale == scale) return entry;
    }
    return null;
  }
}
