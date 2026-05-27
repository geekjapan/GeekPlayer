import 'models/episode.dart';
import 'models/site.dart';
import 'models/work.dart';
import 'models/work_id.dart';
import 'models/work_query.dart';

/// Site-agnostic interface for fetching online novel works and
/// episodes. Concrete implementations are provided by the
/// `add-narou-novel-reader` and `add-kakuyomu-novel-reader` changes.
///
/// See design.md D1 for the rationale behind returning
/// `Stream<Episode>` from [fetchEpisodes] (uniform handling of
/// "all-at-once" sources like なろう公式 API and "iterate the table of
/// contents one URL at a time" sources like カクヨム).
///
/// Implementations MUST:
///   - Expose their identifying [Site] via [site].
///   - Apply the responsible-fetching rules (rate limit, robots.txt,
///     backoff) inside their methods.
///   - NOT persist bodies fetched by [fetchEpisodeBody]; persistence
///     happens only in `LibraryRepository.addToLibrary` (design.md D3).
abstract interface class NovelRepository {
  /// Identifier of this repository's source.
  Site get site;

  /// Search / list works matching [query]. Returned [Work]s carry the
  /// minimum metadata required by the home / search screens; bodies
  /// are not pre-fetched.
  Future<List<Work>> searchWorks(WorkQuery query);

  /// Fetch a single work by its composite id.
  Future<Work> fetchWork(WorkId id);

  /// Fetch episodes for a work as a [Stream] (progress-friendly).
  ///
  /// Emits each [Episode] as soon as its metadata is known, then
  /// closes via `done`. Errors propagate via `Stream.error` and abort
  /// the iteration (consumers re-subscribe to retry).
  Stream<Episode> fetchEpisodes(WorkId workId);

  /// Fetch a single episode's body. Pure: no persistence. Must apply
  /// rate-limit / robots / backoff under the hood.
  Future<EpisodeBody> fetchEpisodeBody(WorkId workId, EpisodeId episodeId);
}
