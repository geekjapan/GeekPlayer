import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../oss_licenses.dart' as oss;
import '../domain/license_entry.dart';

part 'oss_license_repository.g.dart';

/// Abstracts the generated `lib/oss_licenses.dart` data so the UI never
/// imports the generated file directly.
///
/// Spec `oss-license-notices` Requirement "License repository abstracts the
/// generated data" — entries are returned sorted by name, deduped, and
/// filtered to drop empty-license rows (e.g. the root `geekplayer` entry
/// and the Flutter SDK stubs which have no upstream LICENSE file).
class OssLicenseRepository {
  const OssLicenseRepository();

  /// Returns an immutable list of [LicenseEntry] values, sorted ascending
  /// by package name, with duplicates collapsed and empty licenses removed.
  List<LicenseEntry> fetchEntries() {
    final Set<String> seen = <String>{};
    final List<LicenseEntry> out = <LicenseEntry>[];
    for (final oss.Package p in oss.allDependencies) {
      // Drop the root project — it's GeekPlayer itself, surfaced via the
      // Apache-2.0 NOTICE section instead.
      if (p.name == oss.thisPackage.name) {
        continue;
      }
      final String text = (p.license ?? '').trim();
      if (text.isEmpty) {
        // Flutter SDK stubs (`flutter_web_plugins`) and similar bundled
        // packages have no LICENSE file; they're covered by Flutter's
        // BSD-3-Clause which is shown via the Flutter dependency itself.
        continue;
      }
      if (!seen.add(p.name)) {
        continue;
      }
      out.add(
        LicenseEntry(
          name: p.name,
          version: p.version,
          licenseText: text,
          homepageUrl: p.homepage ?? p.repository,
        ),
      );
    }
    out.sort(
      (LicenseEntry a, LicenseEntry b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return List<LicenseEntry>.unmodifiable(out);
  }
}

@Riverpod(keepAlive: true)
OssLicenseRepository ossLicenseRepository(Ref ref) =>
    const OssLicenseRepository();
