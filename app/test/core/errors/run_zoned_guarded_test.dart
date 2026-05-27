import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';
import 'package:geekplayer/core/errors/app_error_logger.dart';
import 'package:logger/logger.dart';

/// Capture log events without rendering them.
class _CapturingFilter extends LogFilter {
  final List<LogEvent> events = [];

  @override
  bool shouldLog(LogEvent event) {
    events.add(event);
    return false;
  }
}

void main() {
  late _CapturingFilter filter;
  late Logger previous;

  setUp(() {
    filter = _CapturingFilter();
    previous = AppErrorLogger.setLoggerForTesting(
      Logger(filter: filter, printer: SimplePrinter()),
    );
  });

  tearDown(() {
    AppErrorLogger.setLoggerForTesting(previous);
  });

  test('uncaught zone error is routed through AppErrorLogger', () async {
    final completer = Completer<void>();
    runZonedGuarded(
      () {
        // ignore: unawaited_futures
        Future<void>.error(const FormatException('boom'));
      },
      (error, stack) {
        AppErrorLogger.log(UnknownError(error, stackTrace: stack));
        completer.complete();
      },
    );
    await completer.future;

    expect(filter.events, hasLength(1));
    final event = filter.events.single;
    expect(event.level, Level.error);
    final payload = event.message as Map<String, Object?>;
    expect(payload['type'], 'UnknownError');
    expect(payload['cause'], contains('FormatException'));
  });

  test(
    'FlutterError.onError can be wrapped to log + delegate to previous handler',
    () {
      var previousCalled = 0;
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        previousCalled++;
      };
      addTearDown(() => FlutterError.onError = originalHandler);

      final wrapped = FlutterError.onError;
      void upgraded(FlutterErrorDetails details) {
        AppErrorLogger.log(
          UnknownError(details.exception, stackTrace: details.stack),
        );
        wrapped?.call(details);
      }

      FlutterError.onError = upgraded;

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: Exception('x'),
          stack: StackTrace.current,
        ),
      );

      expect(filter.events, hasLength(1));
      expect(filter.events.single.level, Level.error);
      expect(previousCalled, 1);
    },
  );
}
