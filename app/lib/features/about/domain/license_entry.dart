import 'package:meta/meta.dart';

/// Value object describing a single OSS dependency's license.
///
/// Spec `oss-license-notices` Requirement "License repository abstracts the
/// generated data" — the UI consumes `LicenseEntry` values, never the raw
/// `oss_licenses.dart` data.
@immutable
class LicenseEntry {
  final String name;
  final String? version;
  final String licenseText;
  final String? homepageUrl;

  const LicenseEntry({
    required this.name,
    required this.version,
    required this.licenseText,
    this.homepageUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseEntry &&
          other.name == name &&
          other.version == version &&
          other.licenseText == licenseText &&
          other.homepageUrl == homepageUrl;

  @override
  int get hashCode => Object.hash(name, version, licenseText, homepageUrl);

  @override
  String toString() => 'LicenseEntry($name@${version ?? "?"})';
}
