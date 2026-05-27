import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/errors/app_error.dart';

/// A guard that exists primarily for its compile-time effect: if a new variant
/// is added to [AppError] without updating this switch, the Dart analyzer
/// fails with `non_exhaustive_switch_expression`. Adding a runtime assertion
/// keeps the function from being tree-shaken in release tests.
int _exhaustiveLabel(AppError e) => switch (e) {
  NetworkUnreachableError() => 1,
  RateLimitError() => 2,
  SiteConsentRequiredError() => 3,
  RobotsDisallowedError() => 4,
  HtmlParseError() => 5,
  FileNotFoundError() => 6,
  UnsupportedFormatError() => 7,
  UpstreamUnavailableError() => 8,
  StorageQuotaError() => 9,
  UnknownError() => 10,
};

void main() {
  test('exhaustive switch enumerates every AppError variant exactly once', () {
    final variants = <AppError>[
      const NetworkUnreachableError(message: 'm'),
      const RateLimitError(message: 'm'),
      const SiteConsentRequiredError(message: 'm', site: 'narou'),
      const RobotsDisallowedError(message: 'm', path: '/'),
      const HtmlParseError(message: 'm'),
      FileNotFoundError(message: 'm', uri: Uri.parse('file:///x')),
      const UnsupportedFormatError(message: 'm'),
      const UpstreamUnavailableError(message: 'm'),
      const StorageQuotaError(message: 'm'),
      UnknownError(const FormatException('x')),
    ];
    expect(variants.length, 10);
    final labels = variants.map(_exhaustiveLabel).toSet();
    expect(labels, equals({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}));
  });
}
