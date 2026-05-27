import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Lightweight Dio logging interceptor (ja-first messages) for the
/// `online-novel-library` infrastructure.
///
/// Kept intentionally simple: only logs method, URI, status, and
/// elapsed time. Body bodies are NOT logged to avoid leaking
/// fetched novel content into logs.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  static const String _startKey = 'geekplayer.log.start';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.extra[_startKey] = DateTime.now();
    _logger.d('[HTTP] → ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final DateTime? start =
        response.requestOptions.extra[_startKey] as DateTime?;
    final Duration elapsed = start == null
        ? Duration.zero
        : DateTime.now().difference(start);
    _logger.d(
      '[HTTP] ← ${response.statusCode} ${response.requestOptions.uri} '
      '(${elapsed.inMilliseconds}ms)',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.w(
      '[HTTP] ✗ ${err.response?.statusCode ?? '-'} '
      '${err.requestOptions.uri}: ${err.message}',
    );
    handler.next(err);
  }
}
