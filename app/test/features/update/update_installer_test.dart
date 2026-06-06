import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/update/update_installer.dart';

void main() {
  group('LaunchUrlUpdateInstaller platform routing', () {
    test(
      'non-Android: hands off via launchFileUrl with a file:// URI',
      () async {
        Uri? launched;
        String? androidPath;
        final installer = LaunchUrlUpdateInstaller(
          platform: () => false,
          launchFileUrl: (Uri uri) async {
            launched = uri;
            return true;
          },
          androidInstall: (String path) async {
            androidPath = path;
          },
        );

        await installer.openForInstall('/tmp/GeekPlayer-0.2.0.dmg');

        expect(launched, Uri.file('/tmp/GeekPlayer-0.2.0.dmg'));
        expect(launched!.scheme, 'file');
        expect(androidPath, isNull, reason: 'Android path must not run');
      },
    );

    test(
      'Android: routes through androidInstall, never a file:// URI',
      () async {
        Uri? launched;
        String? androidPath;
        final installer = LaunchUrlUpdateInstaller(
          platform: () => true,
          launchFileUrl: (Uri uri) async {
            launched = uri;
            return true;
          },
          androidInstall: (String path) async {
            androidPath = path;
          },
        );

        await installer.openForInstall('/data/cache/GeekPlayer-0.2.0.apk');

        expect(androidPath, '/data/cache/GeekPlayer-0.2.0.apk');
        expect(
          launched,
          isNull,
          reason: 'must not pass a file:// URI on Android',
        );
      },
    );

    test('non-Android: throws when launchFileUrl returns false', () async {
      final installer = LaunchUrlUpdateInstaller(
        platform: () => false,
        launchFileUrl: (Uri uri) async => false,
        androidInstall: (String path) async {},
      );

      expect(
        () => installer.openForInstall('/tmp/x.dmg'),
        throwsA(isA<Exception>()),
      );
    });

    test('Android: propagates androidInstall failure', () async {
      final installer = LaunchUrlUpdateInstaller(
        platform: () => true,
        launchFileUrl: (Uri uri) async => true,
        androidInstall: (String path) async {
          throw Exception('installer unavailable');
        },
      );

      expect(
        () => installer.openForInstall('/data/cache/x.apk'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
