/// Sealed hierarchy of errors raised by `NovelRepository` and the
/// surrounding Library / consent layers.
///
/// Distinct from `core/network/errors.dart` (transport-layer); the two
/// hierarchies may compose — e.g. a site-specific repository can wrap a
/// [RobotsDisallowedError] inside its own subclass if it wants to attach
/// site context.
library;

import 'models/site.dart';
import 'models/work_id.dart';

/// Base sealed class for the novel domain.
sealed class NovelRepositoryError implements Exception {
  const NovelRepositoryError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The user has not granted (or has revoked) consent for the [site],
/// so no network call MAY be issued. Thrown synchronously by the
/// `ConsentGuardedRepository` decorator before any underlying call.
final class SiteConsentRequiredError extends NovelRepositoryError {
  const SiteConsentRequiredError(super.message, {required this.site});

  final Site site;
}

/// Reserved (not raised in this change). Kept here so site-specific
/// changes (`add-kakuyomu-novel-reader`, `add-narou-novel-reader`)
/// share a single exception type for HTML structure-mismatch failures.
final class HtmlParseError extends NovelRepositoryError {
  const HtmlParseError(super.message, {this.url});

  final String? url;
}

/// The requested Work does not exist on the source (or was removed).
final class WorkNotFoundError extends NovelRepositoryError {
  const WorkNotFoundError(super.message, {required this.workId});

  final WorkId workId;
}

/// The requested Episode does not exist for the given Work.
final class EpisodeNotFoundError extends NovelRepositoryError {
  const EpisodeNotFoundError(
    super.message, {
    required this.workId,
    required this.episodeIndex,
  });

  final WorkId workId;
  final int episodeIndex;
}
