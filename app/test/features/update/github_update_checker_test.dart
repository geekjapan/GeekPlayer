import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/features/update/github_update_checker.dart';
import 'package:geekplayer/features/update/update_checker.dart';

// ---------------------------------------------------------------------------
// Fake HttpClient infrastructure
// ---------------------------------------------------------------------------

class _FakeHttpOverrides extends HttpOverrides {
  _FakeHttpOverrides({required this.handler});
  final Future<HttpClientResponse> Function() handler;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient(handler: handler);
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({required this.handler});
  final Future<HttpClientResponse> Function() handler;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(handler);

  // Stubs for interface compliance
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._handler);
  final Future<HttpClientResponse> Function() _handler;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() => _handler();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({required this.statusCode, required this._body});

  @override
  final int statusCode;
  final String _body;

  Stream<List<int>> get _bytes => Stream.value(utf8.encode(_body));

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _bytes.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ---------------------------------------------------------------------------
// Helper to run checker with a canned HTTP response.
// ---------------------------------------------------------------------------
Future<UpdateResult> _check(
  String currentVersion, {
  required int status,
  required String body,
}) async {
  late UpdateResult result;
  await HttpOverrides.runWithHttpOverrides(
    () async {
      final checker = GithubUpdateChecker();
      result = await checker.checkForUpdate(currentVersion);
    },
    _FakeHttpOverrides(
      handler: () async =>
          _FakeHttpClientResponse(statusCode: status, body: body),
    ),
  );
  return result;
}

String _releaseJson({required String tagName, String? htmlUrl}) =>
    jsonEncode(<String, dynamic>{
      'tag_name': tagName,
      'html_url':
          htmlUrl ??
          'https://github.com/geekjapan/GeekPlayer/releases/tag/$tagName',
    });

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GithubUpdateChecker', () {
    test('returns UpdateAvailable when tag is newer (v-prefixed)', () async {
      final result = await _check(
        '0.1.0',
        status: 200,
        body: _releaseJson(tagName: 'v0.2.0'),
      );
      expect(result, isA<UpdateAvailable>());
      final ua = result as UpdateAvailable;
      expect(ua.latestVersion, '0.2.0');
      expect(ua.releaseUrl, contains('v0.2.0'));
    });

    test('returns UpdateAvailable when tag is newer (no v-prefix)', () async {
      final result = await _check(
        '0.1.0',
        status: 200,
        body: _releaseJson(tagName: '0.2.0'),
      );
      expect(result, isA<UpdateAvailable>());
    });

    test('returns UpToDate when versions match', () async {
      final result = await _check(
        '0.2.0',
        status: 200,
        body: _releaseJson(tagName: 'v0.2.0'),
      );
      expect(result, isA<UpToDate>());
    });

    test('returns UpToDate when running version is newer', () async {
      final result = await _check(
        '0.3.0',
        status: 200,
        body: _releaseJson(tagName: 'v0.2.0'),
      );
      expect(result, isA<UpToDate>());
    });

    test('returns UpToDate for malformed tag name', () async {
      final result = await _check(
        '0.1.0',
        status: 200,
        body: _releaseJson(tagName: 'release/0.2.0'),
      );
      expect(result, isA<UpToDate>());
    });

    test('returns UpToDate for tag with non-numeric segment', () async {
      final result = await _check(
        '0.1.0',
        status: 200,
        body: _releaseJson(tagName: 'v0.2.0-beta'),
      );
      // "0.2.0-beta" → split('.') gives ["0","2","0-beta"] → int.tryParse("0-beta") == null
      expect(result, isA<UpToDate>());
    });

    test('throws UpstreamUnavailableError on HTTP 500', () async {
      expect(
        () => _check('0.1.0', status: 500, body: 'Internal Server Error'),
        throwsA(
          isA<UpstreamUnavailableError>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('throws UpstreamUnavailableError on HTTP 404', () async {
      expect(
        () => _check('0.1.0', status: 404, body: 'Not Found'),
        throwsA(isA<UpstreamUnavailableError>()),
      );
    });

    test('throws NetworkUnreachableError on SocketException', () async {
      expect(() async {
        await HttpOverrides.runWithHttpOverrides(
          () async {
            final checker = GithubUpdateChecker();
            await checker.checkForUpdate('0.1.0');
          },
          _FakeHttpOverrides(
            handler: () async =>
                throw const SocketException('Network unreachable'),
          ),
        );
      }, throwsA(isA<NetworkUnreachableError>()));
    });

    test('minor-only bump is detected', () async {
      final result = await _check(
        '0.1.9',
        status: 200,
        body: _releaseJson(tagName: 'v0.2.0'),
      );
      expect(result, isA<UpdateAvailable>());
    });

    test('patch-only bump is detected', () async {
      final result = await _check(
        '0.1.0',
        status: 200,
        body: _releaseJson(tagName: 'v0.1.1'),
      );
      expect(result, isA<UpdateAvailable>());
    });
  });
}
