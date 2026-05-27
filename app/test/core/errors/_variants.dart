import 'package:geekplayer/core/errors/app_error.dart';

/// All ten [AppError] variants instantiated with representative values.
/// Shared across widget tests that exercise every variant.
List<AppError> get allErrorVariants => <AppError>[
  const NetworkUnreachableError(message: 'offline'),
  const RateLimitError(message: 'rate', retryAfter: Duration(seconds: 5)),
  const SiteConsentRequiredError(message: 'consent', site: 'kakuyomu'),
  const RobotsDisallowedError(message: 'robots', path: '/x'),
  const HtmlParseError(message: 'parse'),
  FileNotFoundError(message: 'file', uri: Uri.parse('file:///a')),
  const UnsupportedFormatError(message: 'fmt', extension: 'flac'),
  const UpstreamUnavailableError(message: '5xx', statusCode: 503),
  const StorageQuotaError(message: 'quota'),
  UnknownError(const FormatException('boom')),
];
