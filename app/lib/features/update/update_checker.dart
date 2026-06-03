/// Interface and result types for the GitHub Releases update check.
///
/// Spec `auto-update` Requirement "App checks GitHub Releases for a newer
/// version" — `UpdateChecker` is abstract so tests can inject a fake.
library;

import 'release_asset.dart';

/// Result of an update check.
sealed class UpdateResult {
  const UpdateResult();
}

/// The running version is current; no action required.
final class UpToDate extends UpdateResult {
  const UpToDate();
}

/// A newer release is available. [latestVersion] is the stripped semver string
/// (e.g. `"0.2.0"`). [releaseUrl] is the GitHub release HTML page URL.
/// [assets] holds the downloadable release assets; may be empty when the API
/// response contained no assets array.
final class UpdateAvailable extends UpdateResult {
  const UpdateAvailable({
    required this.latestVersion,
    required this.releaseUrl,
    this.assets = const [],
  });

  final String latestVersion;
  final String releaseUrl;
  final List<ReleaseAsset> assets;
}

/// Checks GitHub Releases for a newer version of GeekPlayer.
///
/// Implementations MUST be injectable (via Riverpod override) and MUST map
/// network / HTTP failures to `NetworkUnreachableError` or
/// `UpstreamUnavailableError`.
abstract class UpdateChecker {
  /// Compares [currentVersion] (e.g. `"0.1.0"`) against the latest
  /// GitHub release and returns [UpdateAvailable] or [UpToDate].
  ///
  /// Throws [NetworkUnreachableError] on connectivity failures.
  /// Throws [UpstreamUnavailableError] on HTTP 4xx/5xx responses.
  Future<UpdateResult> checkForUpdate(String currentVersion);
}
