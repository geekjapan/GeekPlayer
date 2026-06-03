import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/update/release_asset.dart';

ReleaseAsset _asset(String name) => ReleaseAsset(
  name: name,
  downloadUrl: 'https://example.com/$name',
  sizeBytes: 1024,
);

void main() {
  group('selectAssetForPlatform', () {
    // ----- macOS -----

    test('macOS prefers .dmg over .zip', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.zip'),
        _asset('GeekPlayer-0.2.0.dmg'),
      ], TargetPlatform.macOS);
      expect(result?.name, 'GeekPlayer-0.2.0.dmg');
    });

    test('macOS falls back to .zip when no .dmg', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.zip'),
      ], TargetPlatform.macOS);
      expect(result?.name, 'GeekPlayer-0.2.0.zip');
    });

    // ----- Windows -----

    test('Windows prefers .exe over .zip', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.zip'),
        _asset('GeekPlayer-0.2.0.exe'),
      ], TargetPlatform.windows);
      expect(result?.name, 'GeekPlayer-0.2.0.exe');
    });

    test('Windows falls back to .zip when no .exe', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.zip'),
      ], TargetPlatform.windows);
      expect(result?.name, 'GeekPlayer-0.2.0.zip');
    });

    // ----- Android -----

    test('Android selects .apk', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.apk'),
        _asset('GeekPlayer-0.2.0.dmg'),
      ], TargetPlatform.android);
      expect(result?.name, 'GeekPlayer-0.2.0.apk');
    });

    // ----- Linux -----

    test('Linux prefers .AppImage over .tar.gz', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.tar.gz'),
        _asset('GeekPlayer-0.2.0.AppImage'),
      ], TargetPlatform.linux);
      expect(result?.name, 'GeekPlayer-0.2.0.AppImage');
    });

    test('Linux falls back to .tar.gz when no .AppImage', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.tar.gz'),
      ], TargetPlatform.linux);
      expect(result?.name, 'GeekPlayer-0.2.0.tar.gz');
    });

    // ----- No match -----

    test('returns null when no compatible asset for platform', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.apk'),
      ], TargetPlatform.macOS);
      expect(result, isNull);
    });

    test('returns null for empty asset list', () {
      final result = selectAssetForPlatform([], TargetPlatform.macOS);
      expect(result, isNull);
    });

    // ----- iOS / Fuchsia (always null) -----

    test('iOS always returns null', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.dmg'),
      ], TargetPlatform.iOS);
      expect(result, isNull);
    });

    test('fuchsia always returns null', () {
      final result = selectAssetForPlatform([
        _asset('GeekPlayer-0.2.0.dmg'),
      ], TargetPlatform.fuchsia);
      expect(result, isNull);
    });

    // ----- ReleaseAsset equality -----

    test('ReleaseAsset equality by fields', () {
      final a = _asset('foo.dmg');
      const b = ReleaseAsset(
        name: 'foo.dmg',
        downloadUrl: 'https://example.com/foo.dmg',
        sizeBytes: 1024,
      );
      expect(a, equals(b));
    });
  });
}
