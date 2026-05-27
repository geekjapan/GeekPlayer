/// Build-time metadata baked in via `--dart-define`.
///
/// Spec `about-screen` Requirement "About screen displays application
/// identity" — when `GIT_SHA` is missing the screen MUST display the
/// literal text `(dev build)` in place of the SHA.
///
/// Release builds:
///   flutter build <target> --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
///
/// See `docs/release.md`.
library;

const String kGitSha = String.fromEnvironment(
  'GIT_SHA',
  defaultValue: 'unknown',
);

/// Returns the SHA for display: passes the raw value through unless it is
/// the `unknown` fallback, in which case `(dev build)` is shown.
String formattedGitSha([String sha = kGitSha]) {
  if (sha.isEmpty || sha == 'unknown') {
    return '(dev build)';
  }
  return sha;
}
