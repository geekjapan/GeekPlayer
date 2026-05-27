/// Shared sealed hierarchy for media playback / viewing sessions.
///
/// Concrete variants live in sibling `part` files so that Dart 3's "sealed
/// class subtypes must live in the same library" constraint is satisfied
/// while keeping each variant's implementation in its own physical file.
///
/// Adding a new variant (e.g. `AudioSession`, `PageSession`) is done by
/// creating `app/lib/core/media/<variant>_session.dart`, declaring
/// `part of 'media_session.dart';` at its top, and adding the matching
/// `part '<variant>_session.dart';` directive below. See [CONVENTIONS.md
/// §10](../../../../docs/CONVENTIONS.md).
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import 'models.dart';

part 'audio_session.dart';
part 'video_session.dart';
// Future:
// part 'page_session.dart';    // v0.2 manga / book

/// Common interface for media sessions across video / audio / page variants.
///
/// All state flows out through broadcast streams; commands are async. After
/// [dispose] is called the streams complete and further command invocations
/// throw [StateError].
sealed class MediaSession {
  /// Position updates (playhead + buffered range). Broadcast stream; the
  /// first event SHOULD be emitted within 500ms of subscription.
  Stream<MediaPosition> get positionStream;

  /// High-level play state transitions. Broadcast stream.
  Stream<MediaPlayState> get playStateStream;

  /// Total media duration once known. Emits `null` until resolved.
  Stream<Duration?> get durationStream;

  /// Last reported speed. Updated synchronously when [setSpeed] succeeds.
  MediaSpeed get speed;

  /// Begin playback (or resume from paused state).
  Future<void> play();

  /// Pause playback.
  Future<void> pause();

  /// Seek to [position]. Implementations clamp to `[0, duration]`.
  Future<void> seek(Duration position);

  /// Change playback rate.
  Future<void> setSpeed(MediaSpeed speed);

  /// Release native resources. Safe to call multiple times.
  Future<void> dispose();
}
