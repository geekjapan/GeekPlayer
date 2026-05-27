import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/oss_licenses.dart';

/// Spec `oss-license-notices` Requirement "OSS license collection is
/// automated at build time" + design.md "Risks / Trade-offs — 主要依存が
/// 出力に含まれることをスナップショットテストで検証".
///
/// This test guards against accidental regressions where `flutter pub add`
/// happens but the contributor forgets to re-run
/// `dart run flutter_oss_licenses:generate -o lib/oss_licenses.dart`.
void main() {
  group('oss_licenses snapshot', () {
    test('major runtime dependencies are present', () {
      final Set<String> names = allDependencies
          .map((Package p) => p.name)
          .toSet();
      const List<String> required = <String>[
        'media_kit',
        'just_audio',
        'drift',
        'dio',
        'flutter_riverpod',
        'html',
        'webfeed_revised',
        'url_launcher',
        'package_info_plus',
      ];
      for (final String dep in required) {
        expect(
          names.contains(dep),
          isTrue,
          reason:
              'Required dep "$dep" missing from oss_licenses.dart — did you '
              'forget `dart run flutter_oss_licenses:generate -o '
              'lib/oss_licenses.dart`?',
        );
      }
    });

    test('every non-SDK / non-root entry has a license body', () {
      // libmpv (LGPL) is NOT a Dart package and is handled by the manual
      // `LgplNoticeSection` widget. For everything `flutter_oss_licenses`
      // does collect, the body should be non-empty so the detail screen
      // can show something — except for:
      //   - the root project itself (license lives in repo /LICENSE)
      //   - Flutter-bundled stubs (`flutter_web_plugins`) which inherit
      //     from the Flutter SDK BSD-3-Clause
      const Set<String> bundledSkip = <String>{
        'geekplayer',
        'flutter_web_plugins',
      };
      final Iterable<Package> withEmptyLicense = allDependencies.where(
        (Package p) =>
            !bundledSkip.contains(p.name) &&
            (p.license ?? '').trim().isEmpty,
      );
      expect(
        withEmptyLicense.map((Package p) => p.name).toList(),
        isEmpty,
        reason:
            'These packages have an empty license body — flutter_oss_licenses '
            'could not find a LICENSE file. Investigate or add to ignore list.',
      );
    });

    test('this package (geekplayer) is included as the root', () {
      expect(thisPackage.name, 'geekplayer');
    });
  });
}
