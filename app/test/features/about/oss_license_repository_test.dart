import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/about/data/oss_license_repository.dart';
import 'package:geekplayer/features/about/domain/license_entry.dart';

void main() {
  group('OssLicenseRepository.fetchEntries', () {
    const OssLicenseRepository repo = OssLicenseRepository();
    final List<LicenseEntry> entries = repo.fetchEntries();

    test('returns non-empty list', () {
      expect(entries, isNotEmpty);
    });

    test('is sorted ascending by name (case-insensitive)', () {
      for (int i = 1; i < entries.length; i++) {
        final String prev = entries[i - 1].name.toLowerCase();
        final String curr = entries[i].name.toLowerCase();
        expect(
          prev.compareTo(curr) <= 0,
          isTrue,
          reason: 'Entries not sorted at index $i: $prev > $curr',
        );
      }
    });

    test('contains no duplicate package names', () {
      final Set<String> seen = <String>{};
      for (final LicenseEntry e in entries) {
        expect(seen.add(e.name), isTrue, reason: 'duplicate: ${e.name}');
      }
    });

    test('every entry has a non-empty license text', () {
      for (final LicenseEntry e in entries) {
        expect(
          e.licenseText.trim(),
          isNotEmpty,
          reason: '${e.name} has empty license',
        );
      }
    });

    test('excludes the root geekplayer package', () {
      expect(entries.any((LicenseEntry e) => e.name == 'geekplayer'), isFalse);
    });

    test('includes major runtime dependencies', () {
      const List<String> expectedNames = <String>[
        'media_kit',
        'just_audio',
        'drift',
        'dio',
        'flutter_riverpod',
        'url_launcher',
      ];
      final Set<String> names = entries.map((LicenseEntry e) => e.name).toSet();
      for (final String n in expectedNames) {
        expect(names.contains(n), isTrue, reason: 'missing $n');
      }
    });
  });
}
