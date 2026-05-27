import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/app_error_logger.dart';
import 'package:logger/logger.dart';

/// In-memory capture of `LogEvent`s for assertions. Bypasses the printer
/// entirely so tests do not depend on the human-readable format.
class _CapturingFilter extends LogFilter {
  final List<LogEvent> events = [];

  @override
  bool shouldLog(LogEvent event) {
    events.add(event);
    return false; // drop, we only want to capture
  }
}

void main() {
  late _CapturingFilter filter;
  late Logger previous;

  setUp(() {
    filter = _CapturingFilter();
    final logger = Logger(filter: filter, printer: SimplePrinter());
    previous = AppErrorLogger.setLoggerForTesting(logger);
  });

  tearDown(() {
    AppErrorLogger.setLoggerForTesting(previous);
  });

  test('RateLimitError logs at warning level with retryAfter payload', () {
    AppErrorLogger.log(
      const RateLimitError(
        message: 'too many',
        retryAfter: Duration(seconds: 5),
      ),
    );

    expect(filter.events, hasLength(1));
    final event = filter.events.single;
    expect(event.level, Level.warning);
    final payload = event.message as Map<String, Object?>;
    expect(payload['type'], 'RateLimitError');
    expect(payload['message'], 'too many');
    expect(payload['retryAfter'], '5s');
  });

  test('UnknownError logs at error level with stackTrace string', () {
    final trace = StackTrace.current;
    AppErrorLogger.log(
      UnknownError(const FormatException('boom'), stackTrace: trace),
    );

    expect(filter.events, hasLength(1));
    final event = filter.events.single;
    expect(event.level, Level.error);
    final payload = event.message as Map<String, Object?>;
    expect(payload['type'], 'UnknownError');
    expect(payload['cause'], contains('FormatException'));
    expect(payload['stackTrace'], trace.toString());
  });

  test('RobotsDisallowedError payload includes path', () {
    AppErrorLogger.log(
      const RobotsDisallowedError(message: 'denied', path: '/admin/'),
    );

    final payload = filter.events.single.message as Map<String, Object?>;
    expect(payload['path'], '/admin/');
    expect(filter.events.single.level, Level.error);
  });

  test('NetworkUnreachableError logs at warning level', () {
    AppErrorLogger.log(const NetworkUnreachableError(message: 'offline'));
    expect(filter.events.single.level, Level.warning);
  });

  group('buildPayload', () {
    test('omits optional fields when null', () {
      final payload = AppErrorLogger.buildPayload(
        const HtmlParseError(message: 'm'),
      );
      expect(payload.containsKey('sourceUrl'), isFalse);
      expect(payload.containsKey('cause'), isFalse);
      expect(payload.containsKey('stackTrace'), isFalse);
    });

    test('includes uri for FileNotFoundError', () {
      final payload = AppErrorLogger.buildPayload(
        FileNotFoundError(message: 'gone', uri: Uri.parse('file:///x.mp4')),
      );
      expect(payload['uri'], 'file:///x.mp4');
    });

    test('includes statusCode for UpstreamUnavailableError', () {
      final payload = AppErrorLogger.buildPayload(
        const UpstreamUnavailableError(message: 'm', statusCode: 503),
      );
      expect(payload['statusCode'], 503);
    });
  });
}
