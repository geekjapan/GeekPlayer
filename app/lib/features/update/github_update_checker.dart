/// GitHub Releases implementation of [UpdateChecker].
///
/// Uses `dart:io` `HttpClient` directly to avoid coupling into the site-
/// scraping Dio infrastructure. See design.md D3.
library;

import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

import '../../core/errors/app_error.dart';
import 'update_checker.dart';

/// Queries `https://api.github.com/repos/geekjapan/GeekPlayer/releases/latest`
/// and compares the `tag_name` field against [currentVersion].
///
/// Spec `auto-update` Requirement "App checks GitHub Releases for a newer
/// version".
final class GithubUpdateChecker implements UpdateChecker {
  GithubUpdateChecker({Logger? logger}) : _log = logger ?? Logger();

  static const String _apiUrl =
      'https://api.github.com/repos/geekjapan/GeekPlayer/releases/latest';

  final Logger _log;

  @override
  Future<UpdateResult> checkForUpdate(String currentVersion) async {
    late final HttpClientResponse response;
    try {
      final HttpClient client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final HttpClientRequest request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');
      response = await request.close();
    } on SocketException catch (e, st) {
      throw NetworkUnreachableError(
        message: 'update check: ${e.message}',
        cause: e,
        stackTrace: st,
      );
    } on HttpException catch (e, st) {
      throw NetworkUnreachableError(
        message: 'update check: ${e.message}',
        cause: e,
        stackTrace: st,
      );
    } on HandshakeException catch (e, st) {
      throw NetworkUnreachableError(
        message: 'update check TLS: $e',
        cause: e,
        stackTrace: st,
      );
    }

    if (response.statusCode != 200) {
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .catchError((_) => '');
      throw UpstreamUnavailableError(
        message: 'GitHub Releases returned ${response.statusCode}',
        statusCode: response.statusCode,
        cause: body.isEmpty ? null : body,
      );
    }

    final String body = await response.transform(utf8.decoder).join();
    final Object? json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      _log.w('GithubUpdateChecker: unexpected JSON shape');
      return const UpToDate();
    }

    final String? tagName = json['tag_name'] as String?;
    final String? htmlUrl = json['html_url'] as String?;

    if (tagName == null || htmlUrl == null) {
      _log.w('GithubUpdateChecker: missing tag_name or html_url');
      return const UpToDate();
    }

    final String? latest = _parseSemver(tagName);
    if (latest == null) {
      _log.d('GithubUpdateChecker: unrecognised tag format "$tagName"');
      return const UpToDate();
    }

    if (_isNewer(latest, currentVersion)) {
      return UpdateAvailable(latestVersion: latest, releaseUrl: htmlUrl);
    }
    return const UpToDate();
  }

  /// Strips a leading `"v"` and validates three-part semver. Returns `null`
  /// if the tag does not match `[v]MAJOR.MINOR.PATCH`.
  static String? _parseSemver(String tag) {
    final String s = tag.startsWith('v') ? tag.substring(1) : tag;
    final List<String> parts = s.split('.');
    if (parts.length != 3) return null;
    if (parts.any((String p) => int.tryParse(p) == null)) return null;
    return s;
  }

  /// Returns `true` when [candidate] is strictly greater than [running].
  /// Both strings MUST be valid three-part semver (validated by [_parseSemver]).
  static bool _isNewer(String candidate, String running) {
    final List<int> c = candidate.split('.').map(int.parse).toList();
    final List<int> r = _parseSemver(running) != null
        ? running.split('.').map(int.parse).toList()
        : <int>[0, 0, 0];
    for (int i = 0; i < 3; i++) {
      if (c[i] > r[i]) return true;
      if (c[i] < r[i]) return false;
    }
    return false;
  }
}
