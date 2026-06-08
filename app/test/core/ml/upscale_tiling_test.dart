import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/ml/upscale_tiling.dart';
import 'package:image/image.dart' as img;

/// Distinct per-pixel RGB so mis-placed tiles are detectable.
img.Image _makeImage(int w, int h) {
  final img.Image image = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      image.setPixelRgb(x, y, (x * 7) & 0xFF, (y * 11) & 0xFF, (x * y) & 0xFF);
    }
  }
  return image;
}

/// Identity "model": output = input (scale 1). Used to verify split→stitch
/// reconstructs the source exactly.
List<ScaledTile> _identity(List<UpscaleTile> tiles) =>
    tiles.map((t) => ScaledTile(tile: t, scaled: t.input)).toList();

/// Nearest-neighbor ×scale of [src] (asymmetric floor), the reference a tiled
/// nearest upscale must reproduce.
img.Image _nearest(img.Image src, int scale) {
  final img.Image out = img.Image(
    width: src.width * scale,
    height: src.height * scale,
  );
  for (int y = 0; y < out.height; y++) {
    for (int x = 0; x < out.width; x++) {
      final p = src.getPixel(x ~/ scale, y ~/ scale);
      out.setPixelRgb(x, y, p.r, p.g, p.b);
    }
  }
  return out;
}

void _expectEqualImages(img.Image a, img.Image b) {
  expect(a.width, b.width);
  expect(a.height, b.height);
  for (int y = 0; y < a.height; y++) {
    for (int x = 0; x < a.width; x++) {
      final pa = a.getPixel(x, y);
      final pb = b.getPixel(x, y);
      if (pa.r != pb.r || pa.g != pb.g || pa.b != pb.b) {
        fail(
          'pixel ($x,$y) differs: '
          '(${pa.r},${pa.g},${pa.b}) vs (${pb.r},${pb.g},${pb.b})',
        );
      }
    }
  }
}

void main() {
  group('planTiles geometry', () {
    test('exact multiple of core needs no remainder tile', () {
      // tileSize 8, overlap 2 → core 4. 8x4 image → 2x1 tiles.
      final tiles = planTiles(_makeImage(8, 4), tileSize: 8, overlap: 2);
      expect(tiles.length, 2);
      for (final t in tiles) {
        expect(t.input.width, 8);
        expect(t.input.height, 8);
        expect(t.overlap, 2);
      }
      expect(tiles[0].validX0, 0);
      expect(tiles[1].validX0, 4);
      expect(tiles.every((t) => t.validW == 4 && t.validH == 4), isTrue);
    });

    test('non-multiple produces a clamped remainder tile', () {
      // core 4, width 10 → tilesX 3 (cols at 0,4,8); last validW = 2.
      final tiles = planTiles(_makeImage(10, 4), tileSize: 8, overlap: 2);
      expect(tiles.length, 3);
      expect(tiles.last.validX0, 8);
      expect(tiles.last.validW, 2); // 10 - 8
      // All tile inputs are still exactly tileSize (edge-replicated).
      expect(
        tiles.every((t) => t.input.width == 8 && t.input.height == 8),
        isTrue,
      );
    });

    test('overlap 0 yields core == tileSize', () {
      final tiles = planTiles(_makeImage(6, 6), tileSize: 3, overlap: 0);
      expect(tiles.length, 4); // ceil(6/3)^2
      expect(tiles.every((t) => t.input.width == 3), isTrue);
    });

    test('rejects tileSize <= 2*overlap', () {
      expect(
        () => planTiles(_makeImage(4, 4), tileSize: 4, overlap: 2),
        throwsArgumentError,
      );
    });
  });

  group('split → stitch roundtrip', () {
    test('identity scale=1 reconstructs the source exactly (with overlap)', () {
      final img.Image src = _makeImage(10, 7);
      final tiles = planTiles(src, tileSize: 8, overlap: 2);
      final out = stitchTiles(
        _identity(tiles),
        srcWidth: 10,
        srcHeight: 7,
        scale: 1,
      );
      _expectEqualImages(out, src);
    });

    test('identity reconstructs with overlap 0', () {
      final img.Image src = _makeImage(9, 5);
      final tiles = planTiles(src, tileSize: 4, overlap: 0);
      final out = stitchTiles(
        _identity(tiles),
        srcWidth: 9,
        srcHeight: 5,
        scale: 1,
      );
      _expectEqualImages(out, src);
    });

    test('tiled nearest ×2 matches whole-image nearest ×2', () {
      final img.Image src = _makeImage(11, 9);
      final tiles = planTiles(src, tileSize: 8, overlap: 2);
      final scaled = tiles
          .map((t) => ScaledTile(tile: t, scaled: _nearest(t.input, 2)))
          .toList();
      final out = stitchTiles(scaled, srcWidth: 11, srcHeight: 9, scale: 2);
      _expectEqualImages(out, _nearest(src, 2));
    });

    test('tiled nearest ×4 matches whole-image nearest ×4', () {
      final img.Image src = _makeImage(7, 6);
      final tiles = planTiles(src, tileSize: 6, overlap: 1);
      final scaled = tiles
          .map((t) => ScaledTile(tile: t, scaled: _nearest(t.input, 4)))
          .toList();
      final out = stitchTiles(scaled, srcWidth: 7, srcHeight: 6, scale: 4);
      _expectEqualImages(out, _nearest(src, 4));
    });

    test('stitch rejects a wrongly-sized scaled tile', () {
      final tiles = planTiles(_makeImage(4, 4), tileSize: 4, overlap: 0);
      final bad = [
        ScaledTile(tile: tiles.first, scaled: img.Image(width: 5, height: 5)),
      ];
      expect(
        () => stitchTiles(bad, srcWidth: 4, srcHeight: 4, scale: 2),
        throwsArgumentError,
      );
    });
  });

  group('divisibility', () {
    test('requiredModulus: 2 for scale 2, else 1', () {
      expect(requiredModulus(2), 2);
      expect(requiredModulus(4), 1);
      expect(requiredModulus(3), 1);
    });

    test('256 satisfies both scale 2 and 4', () {
      expect(tileSizeSatisfiesScale(256, 2), isTrue);
      expect(tileSizeSatisfiesScale(256, 4), isTrue);
    });

    test('odd tile size fails scale 2', () {
      expect(tileSizeSatisfiesScale(255, 2), isFalse);
      expect(tileSizeSatisfiesScale(255, 4), isTrue);
    });
  });
}
