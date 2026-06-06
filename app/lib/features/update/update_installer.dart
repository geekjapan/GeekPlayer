/// In-app update installer / file-handoff.
///
/// `UpdateInstaller` is abstract so tests can inject a fake via Riverpod
/// override. `LaunchUrlUpdateInstaller` is the live implementation.
library;

import 'dart:io' show Platform;

import 'package:open_filex/open_filex.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'update_installer.g.dart';

/// Hands a downloaded file off to the OS for installation or opening.
abstract class UpdateInstaller {
  /// Opens [filePath] via the OS default handler (e.g. Finder, Explorer, APK
  /// installer). Throws if the URI cannot be launched.
  Future<void> openForInstall(String filePath);
}

/// Selects the Android branch. Injected so tests can drive either path on a
/// host where `Platform.isAndroid` is always false.
typedef IsAndroidResolver = bool Function();

/// Launches a `file://` URI handoff (desktop/Linux). Returns whether the OS
/// accepted the launch.
typedef LaunchFileUrl = Future<bool> Function(Uri uri);

/// Fires the Android package-installer intent for the downloaded `.apk`.
typedef AndroidInstall = Future<void> Function(String filePath);

Future<bool> _defaultLaunchFileUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Default Android handoff: `open_filex` builds a `FileProvider` content URI
/// (authority `${applicationId}.fileProvider.com.crazecoder.openfile`,
/// registered by the package's bundled manifest via manifest merge) and
/// launches `ACTION_VIEW` with the apk mime, which resolves to the system
/// installer. A non-`done` result is treated as a failure.
Future<void> _defaultAndroidInstall(String filePath) async {
  final OpenResult result = await OpenFilex.open(filePath);
  if (result.type != ResultType.done) {
    throw Exception(
      'Android install handoff failed for $filePath: '
      '${result.type} (${result.message})',
    );
  }
}

/// Live [UpdateInstaller] that routes the OS handoff per platform (ADR-0007
/// distribution model / `auto-update` capability):
///
/// - **Android**: launches the package-installer intent via a `FileProvider`
///   `content://` URI (`open_filex`). A `file://` URI is never passed to the
///   installer (it raises `FileUriExposedException` on Android 7+).
/// - **macOS / Windows / Linux**: `launchUrl(Uri.file(path))` as before.
///
/// The three seams default to the production functions and are injected by
/// tests so both branches are exercised on a host without a device.
final class LaunchUrlUpdateInstaller implements UpdateInstaller {
  const LaunchUrlUpdateInstaller({
    IsAndroidResolver? platform,
    LaunchFileUrl? launchFileUrl,
    AndroidInstall? androidInstall,
  }) : _isAndroid = platform ?? _platformIsAndroid,
       _launchFileUrl = launchFileUrl ?? _defaultLaunchFileUrl,
       _androidInstall = androidInstall ?? _defaultAndroidInstall;

  final IsAndroidResolver _isAndroid;
  final LaunchFileUrl _launchFileUrl;
  final AndroidInstall _androidInstall;

  @override
  Future<void> openForInstall(String filePath) async {
    if (_isAndroid()) {
      await _androidInstall(filePath);
      return;
    }
    final Uri uri = Uri.file(filePath);
    final bool launched = await _launchFileUrl(uri);
    if (!launched) {
      throw Exception('OS handoff could not open $filePath');
    }
  }
}

bool _platformIsAndroid() => Platform.isAndroid;

/// Provides the live [UpdateInstaller] implementation.
///
/// Tests override via:
/// ```dart
/// updateInstallerProvider.overrideWithValue(FakeUpdateInstaller())
/// ```
@Riverpod(keepAlive: true)
UpdateInstaller updateInstaller(Ref ref) => const LaunchUrlUpdateInstaller();
