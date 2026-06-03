/// GitHub release asset value type and platform-specific asset selector.
library;

import 'package:flutter/foundation.dart';

/// A single downloadable asset attached to a GitHub release.
@immutable
final class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  /// Asset filename (e.g. `"GeekPlayer-0.2.0.dmg"`).
  final String name;

  /// `browser_download_url` from the GitHub Releases API.
  final String downloadUrl;

  /// `size` field from the GitHub Releases API (bytes).
  final int sizeBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReleaseAsset &&
          other.name == name &&
          other.downloadUrl == downloadUrl &&
          other.sizeBytes == sizeBytes);

  @override
  int get hashCode => Object.hash(name, downloadUrl, sizeBytes);

  @override
  String toString() => 'ReleaseAsset($name, $sizeBytes bytes)';
}

/// Selects the best release asset for [platform] from [assets].
///
/// Priority per platform:
/// - macOS   : `.dmg` first, `.zip` fallback
/// - Windows : `.exe` first, `.zip` fallback
/// - Android : `.apk`
/// - Linux   : `.AppImage` first, `.tar.gz` fallback
///
/// Returns `null` when no compatible asset is found. The caller MUST fall back
/// to opening the GitHub release page in a browser in that case.
ReleaseAsset? selectAssetForPlatform(
  List<ReleaseAsset> assets,
  TargetPlatform platform,
) {
  switch (platform) {
    case TargetPlatform.macOS:
      return _first(assets, '.dmg') ?? _first(assets, '.zip');
    case TargetPlatform.windows:
      return _first(assets, '.exe') ?? _first(assets, '.zip');
    case TargetPlatform.android:
      return _first(assets, '.apk');
    case TargetPlatform.linux:
      return _first(assets, '.AppImage') ?? _first(assets, '.tar.gz');
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return null;
  }
}

ReleaseAsset? _first(List<ReleaseAsset> assets, String suffix) {
  for (final a in assets) {
    if (a.name.endsWith(suffix)) return a;
  }
  return null;
}
