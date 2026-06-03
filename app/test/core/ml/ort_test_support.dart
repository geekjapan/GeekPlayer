import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

/// Preloads the ONNX Runtime native library by absolute path.
///
/// The `onnxruntime` package opens its native lib by bare name (e.g.
/// `libonnxruntime.1.15.1.dylib`), which only resolves inside a full app
/// bundle. Under plain `flutter test` (flutter_tester) there is no bundle, so
/// we locate the lib via `.dart_tool/package_config.json` and preload it by
/// absolute path; the package's subsequent bare-name `dlopen` then matches the
/// already-loaded image.
///
/// (`Isolate.resolvePackageUri` is unsupported under flutter_tester, hence the
/// package_config.json lookup.)
///
/// Returns `true` if ORT is loadable on this platform, `false` otherwise.
/// Tests that need real inference should `skip` when this returns `false` so
/// the suite stays green where the native lib is unavailable to the host.
Future<bool> ensureOrtLoadable() async {
  try {
    final String? rel = _platformLibRelPath();
    if (rel == null) return false;
    final String? pkgRoot = _resolvePackageRoot('onnxruntime');
    if (pkgRoot == null) return false;
    final String libPath = '$pkgRoot/$rel';
    if (!File(libPath).existsSync()) return false;
    DynamicLibrary.open(libPath);
    return true;
  } catch (_) {
    return false;
  }
}

/// Resolves a package's root directory via `.dart_tool/package_config.json`,
/// searching the test CWD and a couple of parents.
String? _resolvePackageRoot(String packageName) {
  for (final String candidate in <String>[
    '.dart_tool/package_config.json',
    '../.dart_tool/package_config.json',
    'app/.dart_tool/package_config.json',
  ]) {
    final File f = File(candidate);
    if (!f.existsSync()) continue;
    final Map<String, dynamic> json =
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final List<dynamic> packages = json['packages'] as List<dynamic>;
    for (final dynamic entry in packages) {
      final Map<String, dynamic> pkg = entry as Map<String, dynamic>;
      if (pkg['name'] == packageName) {
        final Uri base = f.absolute.uri;
        final Uri root = base.resolve(pkg['rootUri'] as String);
        return root.toFilePath();
      }
    }
  }
  return null;
}

String? _platformLibRelPath() {
  if (Platform.isMacOS) return 'macos/libonnxruntime.1.15.1.dylib';
  if (Platform.isLinux) return 'linux/libonnxruntime.so.1.15.1';
  if (Platform.isWindows) return 'windows/onnxruntime.dll';
  // Android/iOS load from the bundled app / process image, not a host path.
  return null;
}
