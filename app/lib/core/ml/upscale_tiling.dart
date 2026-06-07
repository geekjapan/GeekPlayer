import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Fixed-shape tiling for ONNX upscale models (ADR-0007, `upscale-image-tiling`).
///
/// NNAPI does not support dynamic input shapes and CoreML prefers fixed shapes,
/// so real upscale models are exported with a fixed square tile edge. This
/// utility splits an arbitrary-size image into uniform `tileSize × tileSize`
/// tiles — every tile is exactly that size, with the right/bottom remainder and
/// the per-tile context border filled by edge replication — and reassembles the
/// model's scaled tiles into a seamless `(W·scale)×(H·scale)` image.
///
/// Geometry (all in source pixels):
/// - `core = tileSize - 2·overlap` is the valid (non-context) stride per tile.
/// - The grid has `ceil(W/core)·ceil(H/core)` tiles.
/// - Each tile's model input window is its valid core grown by [overlap] on all
///   sides (edge-replicated where it exceeds the source), so a convolutional
///   model sees neighbours; the `overlap` border is cropped (×scale) off the
///   scaled output before stitching, removing seam artifacts.
///
/// Because [tileSize] is fixed and chosen divisible by the scale's modulus
/// (e.g. 256 is divisible by 2 and 4), the model input always satisfies the
/// scale-dependent divisibility requirement without extra reflect-padding.
///
/// All functions here are pure and deterministic — no model, GPU, or network —
/// so the split→reassemble contract is unit-testable on every CI host.
@immutable
class UpscaleTile {
  const UpscaleTile({
    required this.input,
    required this.validX0,
    required this.validY0,
    required this.validW,
    required this.validH,
    required this.overlap,
  });

  /// The model input image, exactly `tileSize × tileSize`.
  final img.Image input;

  /// Top-left of this tile's valid core, in source-image coordinates.
  final int validX0;
  final int validY0;

  /// Size of the valid core in source pixels (may be `< core` at the right /
  /// bottom edges). The core sits at offset ([overlap], [overlap]) inside
  /// [input].
  final int validW;
  final int validH;

  /// Context border (px) on each side of the valid core inside [input].
  final int overlap;
}

/// Splits [src] into fixed `tileSize × tileSize` tiles with an [overlap]-px
/// edge-replicated context border around each valid core.
///
/// Throws [ArgumentError] when `tileSize <= 2·overlap` (no valid core remains)
/// or when arguments are non-positive.
List<UpscaleTile> planTiles(
  img.Image src, {
  required int tileSize,
  int overlap = 10,
}) {
  if (tileSize <= 0) {
    throw ArgumentError.value(tileSize, 'tileSize', 'must be > 0');
  }
  if (overlap < 0) {
    throw ArgumentError.value(overlap, 'overlap', 'must be >= 0');
  }
  final int core = tileSize - 2 * overlap;
  if (core <= 0) {
    throw ArgumentError('tileSize ($tileSize) must exceed 2*overlap ($overlap)');
  }

  final int tilesX = (src.width + core - 1) ~/ core;
  final int tilesY = (src.height + core - 1) ~/ core;
  final List<UpscaleTile> tiles = <UpscaleTile>[];

  for (int ty = 0; ty < tilesY; ty++) {
    for (int tx = 0; tx < tilesX; tx++) {
      final int validX0 = tx * core;
      final int validY0 = ty * core;
      final int validW = (src.width - validX0).clamp(0, core);
      final int validH = (src.height - validY0).clamp(0, core);
      if (validW == 0 || validH == 0) continue;

      // Window top-left in source coords (may be negative → edge-replicated).
      final int winX0 = validX0 - overlap;
      final int winY0 = validY0 - overlap;
      final img.Image input = img.Image(width: tileSize, height: tileSize);
      for (int y = 0; y < tileSize; y++) {
        final int sy = (winY0 + y).clamp(0, src.height - 1);
        for (int x = 0; x < tileSize; x++) {
          final int sx = (winX0 + x).clamp(0, src.width - 1);
          final img.Pixel p = src.getPixel(sx, sy);
          input.setPixelRgb(x, y, p.r, p.g, p.b);
        }
      }
      tiles.add(
        UpscaleTile(
          input: input,
          validX0: validX0,
          validY0: validY0,
          validW: validW,
          validH: validH,
          overlap: overlap,
        ),
      );
    }
  }
  return tiles;
}

/// A scaled tile result: the [tile] it came from and the model's [scaled]
/// output (expected to be `tile.input` scaled by `scale`, i.e.
/// `tileSize·scale` square).
@immutable
class ScaledTile {
  const ScaledTile({required this.tile, required this.scaled});

  final UpscaleTile tile;
  final img.Image scaled;
}

/// Reassembles [results] into the final `(srcWidth·scale)×(srcHeight·scale)`
/// image, cropping each tile's `overlap·scale` context border and writing only
/// the scaled valid core into place — yielding a seamless result.
///
/// Throws [ArgumentError] on a non-positive [scale] or a tile whose scaled size
/// does not match its input size times [scale].
img.Image stitchTiles(
  List<ScaledTile> results, {
  required int srcWidth,
  required int srcHeight,
  required int scale,
}) {
  if (scale <= 0) {
    throw ArgumentError.value(scale, 'scale', 'must be > 0');
  }
  final img.Image out = img.Image(width: srcWidth * scale, height: srcHeight * scale);
  for (final ScaledTile r in results) {
    final UpscaleTile t = r.tile;
    final int expected = t.input.width * scale;
    if (r.scaled.width != expected || r.scaled.height != expected) {
      throw ArgumentError(
        'scaled tile is ${r.scaled.width}x${r.scaled.height}, '
        'expected ${expected}x$expected (input ${t.input.width} * scale $scale)',
      );
    }
    final int srcCropX = t.overlap * scale;
    final int srcCropY = t.overlap * scale;
    final int dstX0 = t.validX0 * scale;
    final int dstY0 = t.validY0 * scale;
    final int coreW = t.validW * scale;
    final int coreH = t.validH * scale;
    for (int y = 0; y < coreH; y++) {
      for (int x = 0; x < coreW; x++) {
        final img.Pixel p = r.scaled.getPixel(srcCropX + x, srcCropY + y);
        out.setPixelRgb(dstX0 + x, dstY0 + y, p.r, p.g, p.b);
      }
    }
  }
  return out;
}

/// The input-edge divisibility modulus required for [scale] (Real-ESRGAN's
/// `mod_scale`): 2 for `scale == 2`, otherwise 1 (no constraint, incl. 4).
/// A fixed [tileSize] divisible by this value satisfies the model with no
/// reflect-padding.
int requiredModulus(int scale) => scale == 2 ? 2 : 1;

/// Whether [tileSize] satisfies the divisibility required for [scale].
bool tileSizeSatisfiesScale(int tileSize, int scale) =>
    tileSize % requiredModulus(scale) == 0;
