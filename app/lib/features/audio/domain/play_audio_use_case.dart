import '../../../core/media/models.dart';
import '../data/audio_repository.dart';

/// "Where should playback start for this track?" use case for audio.
///
/// Same shape as the video equivalent: resume from the saved position
/// unless within [kEndOfPlaybackThreshold] of the known duration (in
/// which case start from `Duration.zero`). Duration is generally not
/// known at file-open time, so [resolveStart] without `knownDuration`
/// returns the saved value verbatim — the controller re-applies the
/// rule via [applyEndOfPlaybackRule] once the duration stream emits.
class PlayAudioUseCase {
  PlayAudioUseCase(this._repository);

  final AudioRepository _repository;

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

  static Duration applyEndOfPlaybackRule(Duration saved, Duration duration) {
    if (duration <= Duration.zero) return saved;
    if (duration - saved <= kEndOfPlaybackThreshold) return Duration.zero;
    return saved;
  }
}
