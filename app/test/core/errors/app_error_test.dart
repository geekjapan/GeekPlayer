import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';

void main() {
  group('AppError variants — construction', () {
    test('NetworkUnreachableError stores message', () {
      const e = NetworkUnreachableError(message: 'offline');
      expect(e.message, 'offline');
      expect(e.cause, isNull);
      expect(e, isA<AppError>());
      expect(e, isA<Exception>());
    });

    test('RateLimitError stores retryAfter', () {
      const e = RateLimitError(
        message: 'slow down',
        retryAfter: Duration(seconds: 30),
      );
      expect(e.retryAfter, const Duration(seconds: 30));
      expect(e.message, 'slow down');
    });

    test('SiteConsentRequiredError stores site identifier', () {
      const e = SiteConsentRequiredError(
        message: 'consent missing',
        site: 'kakuyomu',
      );
      expect(e.site, 'kakuyomu');
    });

    test('RobotsDisallowedError stores path', () {
      const e = RobotsDisallowedError(message: 'blocked', path: '/private/');
      expect(e.path, '/private/');
    });

    test('HtmlParseError stores optional sourceUrl', () {
      const e = HtmlParseError(
        message: 'shape changed',
        sourceUrl: 'https://example.com/x',
      );
      expect(e.sourceUrl, 'https://example.com/x');

      const eNoUrl = HtmlParseError(message: 'shape changed');
      expect(eNoUrl.sourceUrl, isNull);
    });

    test('FileNotFoundError stores Uri', () {
      final uri = Uri.parse('file:///tmp/x.mp4');
      final e = FileNotFoundError(message: 'gone', uri: uri);
      expect(e.uri, uri);
    });

    test('UnsupportedFormatError stores extension', () {
      const e = UnsupportedFormatError(message: 'nope', extension: 'flac');
      expect(e.extension, 'flac');
    });

    test('UpstreamUnavailableError stores statusCode', () {
      const e = UpstreamUnavailableError(message: '5xx', statusCode: 503);
      expect(e.statusCode, 503);
    });

    test('StorageQuotaError stores requestedBytes', () {
      const e = StorageQuotaError(message: 'full', requestedBytes: 1 << 20);
      expect(e.requestedBytes, 1 << 20);
    });

    test('UnknownError wraps an arbitrary exception', () {
      final original = const FormatException('bad json');
      final e = UnknownError(original);
      expect(e.message, original.toString());
      expect(e.cause, same(original));
      expect(e.original, same(original));
      expect(e.runtimeType.toString(), 'UnknownError');
    });

    test('UnknownError preserves stackTrace when provided', () {
      final trace = StackTrace.current;
      final e = UnknownError(ArgumentError('x'), stackTrace: trace);
      expect(e.stackTrace, same(trace));
    });
  });

  group('AppError equality & hashCode', () {
    test('equal RobotsDisallowedError with different cause are still equal', () {
      final a = RobotsDisallowedError(
        message: 'denied',
        path: '/admin/',
        cause: Exception('first'),
      );
      final b = RobotsDisallowedError(
        message: 'denied',
        path: '/admin/',
        cause: Exception('second'),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('RateLimitError equality discriminates retryAfter', () {
      const a = RateLimitError(message: 'x', retryAfter: Duration(seconds: 5));
      const b = RateLimitError(message: 'x', retryAfter: Duration(seconds: 5));
      const c = RateLimitError(message: 'x', retryAfter: Duration(seconds: 6));
      expect(a, equals(b));
      expect(a == c, isFalse);
    });

    test('Different variants with same message are not equal', () {
      const a = NetworkUnreachableError(message: 'm');
      const b = HtmlParseError(message: 'm');
      expect(a == b, isFalse);
    });

    test('UnknownError equality ignores wrapped value identity', () {
      final a = UnknownError(const FormatException('x'));
      final b = UnknownError(const FormatException('x'));
      // toString() of FormatException with same argument is identical, so
      // messages match.
      expect(a, equals(b));
    });
  });

  group('AppError toString', () {
    test('includes runtimeType and message', () {
      const e = NetworkUnreachableError(message: 'offline');
      expect(e.toString(), contains('NetworkUnreachableError'));
      expect(e.toString(), contains('offline'));
    });

    test('mentions cause when present', () {
      const e = HtmlParseError(
        message: 'shape changed',
        cause: FormatException('x'),
      );
      expect(e.toString(), contains('caused by'));
    });
  });
}
