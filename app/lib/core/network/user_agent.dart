/// User-Agent string construction for outbound HTTP from GeekPlayer.
///
/// Returns the canonical UA mandated by
/// [ADR-0001](../../../../docs/adr/0001-online-novel-fetch-policy.md)
/// §取得方針-4 and [ADR-0003](../../../../docs/adr/0003-narou-content-fetch-policy.md):
///
///     GeekPlayer/<version> (+https://github.com/geekjapan/GeekPlayer; personal-use)
///
/// [version] is typically sourced from `package_info_plus`'
/// `PackageInfo.fromPlatform().version`. The exact value is identifying us
/// to the upstream site, so we keep it monotonic (semver-shaped).
String buildUserAgent(String version) {
  final String trimmed = version.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(version, 'version', 'must not be empty');
  }
  return 'GeekPlayer/$trimmed (+https://github.com/geekjapan/GeekPlayer; personal-use)';
}

/// HTTP header name. Defined here so callers don't typo `User-Agent`.
const String kUserAgentHeader = 'User-Agent';
