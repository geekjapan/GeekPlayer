import 'dart:math' show Random;

import 'package:flutter/foundation.dart';

import 'audio_track.dart';

/// Repeat behaviour cycled by the player UI. `none` = stop when the
/// queue's last track ends, `all` = wrap to the first, `one` = repeat
/// the current track indefinitely.
enum RepeatMode { none, all, one }

/// In-memory queue (no persistence — design.md D3). Holds the ordered
/// list of [AudioTrack]s the user is currently playing through, plus
/// the current index and the shuffle / repeat flags.
///
/// The class is immutable; mutations return a new instance so the
/// owning Riverpod notifier can `state = state.copyWith(...)` cleanly.
@immutable
class AudioQueue {
  AudioQueue({
    required this.tracks,
    this.currentIndex = 0,
    this.shuffle = false,
    this.repeat = RepeatMode.none,
    List<int>? shuffledOrder,
  })  : assert(
          tracks.isEmpty || (currentIndex >= 0 && currentIndex < tracks.length),
          'currentIndex out of range',
        ),
        shuffledOrder =
            shuffledOrder ?? List<int>.generate(tracks.length, (int i) => i);

  /// Empty queue used as the initial state.
  static final AudioQueue empty = AudioQueue(
    tracks: const <AudioTrack>[],
  );

  final List<AudioTrack> tracks;
  final int currentIndex;
  final bool shuffle;
  final RepeatMode repeat;

  /// Indirection list used when [shuffle] is on. Maps "logical play
  /// position" → "index into [tracks]". When [shuffle] is off this is
  /// just `[0, 1, 2, …]`. Stored explicitly so the order is stable
  /// across [copyWith] calls.
  final List<int> shuffledOrder;

  bool get isEmpty => tracks.isEmpty;
  int get length => tracks.length;

  AudioTrack? get current =>
      tracks.isEmpty ? null : tracks[currentIndex];

  /// Logical (post-shuffle) position of [currentIndex] within
  /// [shuffledOrder]. Used by [skipNext] / [skipPrevious] to walk the
  /// queue in shuffled order.
  int get _logicalIndex => shuffledOrder.indexOf(currentIndex);

  /// Advance to the next track. Honors [repeat]:
  ///   - `one`: stay on the current track (caller re-seeks to 0)
  ///   - `all`: wrap to the first logical track when at the tail
  ///   - `none`: return `null` to indicate "end of queue"
  AudioQueue? skipNext() {
    if (tracks.isEmpty) return null;
    if (repeat == RepeatMode.one) {
      // Caller seeks to 0; the queue itself doesn't change.
      return this;
    }
    final int logical = _logicalIndex;
    final int next = logical + 1;
    if (next >= tracks.length) {
      if (repeat == RepeatMode.all) {
        return copyWith(currentIndex: shuffledOrder.first);
      }
      return null;
    }
    return copyWith(currentIndex: shuffledOrder[next]);
  }

  /// Step to the previous track. When the user is already on the first
  /// logical track this is a no-op (the caller seeks to 0).
  AudioQueue skipPrevious() {
    if (tracks.isEmpty) return this;
    final int logical = _logicalIndex;
    if (logical <= 0) return this;
    return copyWith(currentIndex: shuffledOrder[logical - 1]);
  }

  /// Toggle [shuffle]. When turning **on**, the current track is
  /// pinned at its current logical position and the *other* tracks are
  /// reshuffled randomly behind it (design.md Q-D1). When turning
  /// **off**, the order reverts to the natural `[0..length)`.
  AudioQueue toggleShuffle({Random? random}) {
    if (tracks.isEmpty) return this;
    final Random rng = random ?? Random();
    if (shuffle) {
      // Off → restore natural order.
      return copyWith(
        shuffle: false,
        shuffledOrder: List<int>.generate(tracks.length, (int i) => i),
      );
    }
    // On → keep current pinned, shuffle the rest.
    final List<int> rest = <int>[
      for (int i = 0; i < tracks.length; i++)
        if (i != currentIndex) i,
    ];
    rest.shuffle(rng);
    final List<int> newOrder = <int>[currentIndex, ...rest];
    return copyWith(shuffle: true, shuffledOrder: newOrder);
  }

  /// Cycle through [RepeatMode.none] → `all` → `one` → `none`.
  AudioQueue cycleRepeat() {
    return copyWith(
      repeat: switch (repeat) {
        RepeatMode.none => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.none,
      },
    );
  }

  /// Replace the [current] track's metadata. Used by the controller
  /// once `audio_metadata_reader` resolves async.
  AudioQueue withCurrentMetadata(AudioMetadata? metadata) {
    if (tracks.isEmpty) return this;
    final List<AudioTrack> next = List<AudioTrack>.of(tracks);
    next[currentIndex] = next[currentIndex].copyWith(metadata: metadata);
    return copyWith(tracks: next);
  }

  AudioQueue copyWith({
    List<AudioTrack>? tracks,
    int? currentIndex,
    bool? shuffle,
    RepeatMode? repeat,
    List<int>? shuffledOrder,
  }) {
    return AudioQueue(
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      shuffledOrder: shuffledOrder ?? this.shuffledOrder,
    );
  }
}
