import 'package:flutter/foundation.dart';

/// Threshold for treating a saved playback position as "watched-to-end".
///
/// If the persisted [ResumePoint] is within this distance of the media
/// duration, [PlayVideoUseCase] will resume from `Duration.zero` instead.
/// See `add-local-video-playback` design.md D ResumePoint section.
const Duration kEndOfPlaybackThreshold = Duration(seconds: 5);

/// Immutable snapshot of a [MediaSession]'s temporal state.
///
/// Carries the current playhead [position] and the buffered range
/// (`[bufferStart, bufferEnd]`) reported by the underlying engine. Buffered
/// range may be empty (`bufferStart == bufferEnd == Duration.zero`) before
/// the engine has loaded any data.
@immutable
class MediaPosition {
  const MediaPosition({
    required this.position,
    this.bufferStart = Duration.zero,
    this.bufferEnd = Duration.zero,
  });

  /// Zero/initial position with no buffered range.
  static const MediaPosition zero = MediaPosition(position: Duration.zero);

  final Duration position;
  final Duration bufferStart;
  final Duration bufferEnd;

  MediaPosition copyWith({
    Duration? position,
    Duration? bufferStart,
    Duration? bufferEnd,
  }) {
    return MediaPosition(
      position: position ?? this.position,
      bufferStart: bufferStart ?? this.bufferStart,
      bufferEnd: bufferEnd ?? this.bufferEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaPosition &&
        other.position == position &&
        other.bufferStart == bufferStart &&
        other.bufferEnd == bufferEnd;
  }

  @override
  int get hashCode => Object.hash(position, bufferStart, bufferEnd);

  @override
  String toString() =>
      'MediaPosition(position: $position, buffer: [$bufferStart, $bufferEnd])';
}

/// Immutable value object for playback speed multiplier.
///
/// `value` MUST be strictly greater than `0`. Constructor throws
/// [ArgumentError] otherwise. Preset values used by the player UI are
/// exposed as static constants.
@immutable
class MediaSpeed {
  MediaSpeed(this.value) {
    if (value <= 0 || value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        value,
        'value',
        'MediaSpeed must be a finite value greater than 0',
      );
    }
  }

  final double value;

  /// UI presets used by the player speed selector. See spec D8.
  static final MediaSpeed x0_5 = MediaSpeed(0.5);
  static final MediaSpeed x0_75 = MediaSpeed(0.75);
  static final MediaSpeed normal = MediaSpeed(1.0);
  static final MediaSpeed x1_25 = MediaSpeed(1.25);
  static final MediaSpeed x1_5 = MediaSpeed(1.5);
  static final MediaSpeed x1_75 = MediaSpeed(1.75);
  static final MediaSpeed x2 = MediaSpeed(2.0);

  static List<MediaSpeed> get presets => <MediaSpeed>[
    x0_5,
    x0_75,
    normal,
    x1_25,
    x1_5,
    x1_75,
    x2,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaSpeed && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MediaSpeed(${value}x)';
}

/// Sealed enumeration of high-level playback states.
///
/// Declared as a `sealed class` (rather than a Dart `enum`) so future
/// variants can carry payload (e.g. `Failed(error)`) without source breaks.
sealed class MediaPlayState {
  const MediaPlayState();

  const factory MediaPlayState.idle() = _Idle;
  const factory MediaPlayState.loading() = _Loading;
  const factory MediaPlayState.playing() = _Playing;
  const factory MediaPlayState.paused() = _Paused;
  const factory MediaPlayState.ended() = _Ended;

  bool get isPlaying => this is _Playing;
  bool get isPaused => this is _Paused;
  bool get isEnded => this is _Ended;
  bool get isLoading => this is _Loading;
  bool get isIdle => this is _Idle;
}

class _Idle extends MediaPlayState {
  const _Idle();
  @override
  bool operator ==(Object other) => other is _Idle;
  @override
  int get hashCode => (_Idle).hashCode;
  @override
  String toString() => 'MediaPlayState.idle';
}

class _Loading extends MediaPlayState {
  const _Loading();
  @override
  bool operator ==(Object other) => other is _Loading;
  @override
  int get hashCode => (_Loading).hashCode;
  @override
  String toString() => 'MediaPlayState.loading';
}

class _Playing extends MediaPlayState {
  const _Playing();
  @override
  bool operator ==(Object other) => other is _Playing;
  @override
  int get hashCode => (_Playing).hashCode;
  @override
  String toString() => 'MediaPlayState.playing';
}

class _Paused extends MediaPlayState {
  const _Paused();
  @override
  bool operator ==(Object other) => other is _Paused;
  @override
  int get hashCode => (_Paused).hashCode;
  @override
  String toString() => 'MediaPlayState.paused';
}

class _Ended extends MediaPlayState {
  const _Ended();
  @override
  bool operator ==(Object other) => other is _Ended;
  @override
  int get hashCode => (_Ended).hashCode;
  @override
  String toString() => 'MediaPlayState.ended';
}
