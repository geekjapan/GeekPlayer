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
  });

  /// Stable identifier of the model family (kebab-case).
  final String modelId;

  /// Model version. The on-disk cache is keyed by `(modelId, version)`.
  final String version;

  /// HTTPS download URL (GitHub Releases).
  final String url;

  /// Expected lowercase-hex SHA-256 digest of the downloaded bytes.
  final String sha256;

  /// Integer upscale factor (2 or 4).
  final int scale;

  /// SPDX-style license identifier of the model weights.
  final String license;

  /// Cache-key segment: `<modelId>/<version>`.
  String get cacheKey => '$modelId/$version';

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
          license == other.license;

  @override
  int get hashCode =>
      Object.hash(modelId, version, url, sha256, scale, license);

  @override
  String toString() =>
      'UpscaleModelEntry($modelId@$version, x$scale, $license)';
}

/// The static, app-bundled catalog of distributable upscale models (ADR-0007).
///
/// Selection is by scale factor: [forScale] maps the configured 2x/4x to the
/// catalog entry to download and run. The `https://github.com/.../models-fixture`
/// URLs are placeholders for the fixture phase (grill Q1=A); a follow-up change
/// swaps in real model URLs/digests without touching the wiring.
class UpscaleModelCatalog {
  const UpscaleModelCatalog._();

  /// 2x fixture (nearest-neighbor Resize ONNX, Apache-2.0, GeekPlayer-authored).
  static const UpscaleModelEntry x2 = UpscaleModelEntry(
    modelId: 'fixture-nearest',
    version: 'x2-2026.06',
    url:
        'https://github.com/geekjapan/GeekPlayer/releases/download/models-fixture/upscale_x2_nearest.onnx',
    sha256: '68eddb443e4a48ed80566a4968bccc3ba47b4241bfeddad959a230ee70946927',
    scale: 2,
    license: 'Apache-2.0',
  );

  /// 4x fixture (nearest-neighbor Resize ONNX, Apache-2.0, GeekPlayer-authored).
  static const UpscaleModelEntry x4 = UpscaleModelEntry(
    modelId: 'fixture-nearest',
    version: 'x4-2026.06',
    url:
        'https://github.com/geekjapan/GeekPlayer/releases/download/models-fixture/upscale_x4_nearest.onnx',
    sha256: 'f5ea497c286ec2df5e787f9c41030f8a7f2ad819fc250895da9d61af2b20d60e',
    scale: 4,
    license: 'Apache-2.0',
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
