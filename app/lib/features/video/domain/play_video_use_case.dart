import '../../../core/media/models.dart';
import '../data/video_repository.dart';

/// "Where should playback start for this URI?" use case.
///
/// Encodes the ResumePoint rule from spec L1 R3: resume from saved
/// position unless within [kEndOfPlaybackThreshold] of the (eventual)
/// duration. Duration is generally unknown at file-open time, so the
/// session-side enforcement of the threshold is also performed here once
/// `[knownDuration]` is supplied — the player screen calls [resolveStart]
/// again on `durationStream` first emit to apply the rule.
class PlayVideoUseCase {
  PlayVideoUseCase(this._repository);

  final VideoRepository _repository;

  /// Resolve a starting [Duration] for [uri]. If [knownDuration] is
  /// supplied, returns `Duration.zero` when the saved position is within
  /// [kEndOfPlaybackThreshold] of it. Otherwise returns the saved value
  /// verbatim (the player UI is expected to re-check once duration is
  /// known).
  Future<Duration> resolveStart(Uri uri, {Duration? knownDuration}) async {
    final Duration? saved = await _repository.loadResumePoint(uri);
    if (saved == null) return Duration.zero;
    if (knownDuration != null) {
      final Duration tailGap = knownDuration - saved;
      if (tailGap <= kEndOfPlaybackThreshold) {
        return Duration.zero;
      }
    }
    return saved;
  }

  /// Apply the end-of-playback threshold rule synchronously. Used once
  /// the player learns the media duration. Returns `Duration.zero` to
  /// indicate the saved point should be discarded; otherwise returns
  /// [saved] unchanged.
  static Duration applyEndOfPlaybackRule(Duration saved, Duration duration) {
    if (duration <= Duration.zero) return saved;
    if (duration - saved <= kEndOfPlaybackThreshold) return Duration.zero;
    return saved;
  }
}
