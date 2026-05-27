import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/exceptions.dart';

/// In-place fallback panel rendered by the reader / work-detail screen
/// when `KakuyomuHtmlSource` / `KakuyomuHtmlParser` throws
/// [KakuyomuParseException]. Provides:
///
///   - 「公式ビューアで開く」 → `url_launcher.launchUrl(externalApplication)`
///   - 「詳細をコピー」 → sanitized diagnostic blob to the clipboard
///     (failed selector, URL, app version, OS name — NO HTML body,
///     NO device id, NO IP)
class ParserFailureFallback extends StatelessWidget {
  const ParserFailureFallback({
    super.key,
    required this.error,
    required this.url,
    this.launchUrlOverride,
  });

  final KakuyomuParseException error;
  final String url;

  /// Injection point for tests — bypass `url_launcher`.
  final Future<bool> Function(Uri uri, {LaunchMode mode})? launchUrlOverride;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            '[!] このページの読み込みに失敗しました。\n'
            'アプリのバージョンを更新するか、公式ビューアで開いてください。',
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton.icon(
                key: const Key('kakuyomu-open-external'),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('公式ビューアで開く'),
                onPressed: () => _launchExternal(context),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('kakuyomu-copy-diagnostic'),
                icon: const Icon(Icons.copy),
                label: const Text('詳細をコピー'),
                onPressed: () => _copyDiagnostic(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternal(BuildContext context) async {
    final Uri uri = Uri.parse(url);
    final Future<bool> Function(Uri, {LaunchMode mode}) launcher =
        launchUrlOverride ?? launchUrl;
    final bool ok = await launcher(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ブラウザを起動できませんでした')));
    }
  }

  Future<void> _copyDiagnostic(BuildContext context) async {
    String version = '';
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {
      version = 'unknown';
    }
    final String diag = buildDiagnostic(
      error: error,
      requestUrl: url,
      appVersion: version,
    );
    await Clipboard.setData(ClipboardData(text: diag));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('診断情報をクリップボードにコピーしました')));
    }
  }
}

/// Build the sanitized diagnostic blob copied by 「詳細をコピー」.
///
/// MUST NOT include: device ID, user IP, HTML response body, cookies.
/// MUST include: failed selector, request URL, app version, OS name.
String buildDiagnostic({
  required KakuyomuParseException error,
  required String requestUrl,
  required String appVersion,
  String? osNameOverride,
}) {
  final String os = osNameOverride ?? _safeOsName();
  return <String>[
    'GeekPlayer Kakuyomu parse failure diagnostic',
    'app version: $appVersion',
    'os: $os',
    'request url: $requestUrl',
    'failed selector: ${error.selector}',
    'message: ${error.message}',
  ].join('\n');
}

String _safeOsName() {
  // Plain `Platform.operatingSystem` is fine on non-web. We use a
  // try/catch so the function still works in unit tests under the
  // bare Dart VM (where Platform is available) and in the web build
  // (where it would throw — though we don't target web in v0.1).
  try {
    // ignore: avoid_print
    return _platformName();
  } catch (_) {
    return 'unknown';
  }
}

String _platformName() {
  // Inline guard to avoid importing dart:io at the top (keeps the
  // file analyzer-clean across web stubs).
  // ignore: do_not_use_environment
  return const String.fromEnvironment('os.name', defaultValue: '');
}
