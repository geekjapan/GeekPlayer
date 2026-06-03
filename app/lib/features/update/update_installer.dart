/// In-app update installer / file-handoff.
///
/// `UpdateInstaller` is abstract so tests can inject a fake via Riverpod
/// override. `LaunchUrlUpdateInstaller` is the live implementation.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'update_installer.g.dart';

/// Hands a downloaded file off to the OS for installation or opening.
abstract class UpdateInstaller {
  /// Opens [filePath] via the OS default handler (e.g. Finder, Explorer, APK
  /// installer). Throws if the URI cannot be launched.
  Future<void> openForInstall(String filePath);
}

/// Live [UpdateInstaller] that calls `launchUrl` with a `file://` URI.
final class LaunchUrlUpdateInstaller implements UpdateInstaller {
  const LaunchUrlUpdateInstaller();

  @override
  Future<void> openForInstall(String filePath) async {
    final Uri uri = Uri.file(filePath);
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('launchUrl could not open $filePath');
    }
  }
}

/// Provides the live [UpdateInstaller] implementation.
///
/// Tests override via:
/// ```dart
/// updateInstallerProvider.overrideWithValue(FakeUpdateInstaller())
/// ```
@Riverpod(keepAlive: true)
UpdateInstaller updateInstaller(Ref ref) => const LaunchUrlUpdateInstaller();
