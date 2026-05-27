import 'package:audio_service/audio_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'audio_handler.dart';

part 'audio_providers.g.dart';

/// Singleton [GeekPlayerAudioHandler] for the running process.
///
/// **Set in `main.dart`** via `audioHandlerInstance` after
/// `AudioService.init` resolves. Reading this provider before that
/// happens throws [StateError] with a message pointing at the wiring
/// gap — that's safer than silently returning `null` and crashing later
/// inside an [AudioSession] command.
@Riverpod(keepAlive: true)
GeekPlayerAudioHandler audioHandler(Ref ref) {
  final GeekPlayerAudioHandler? handler = _instance;
  if (handler == null) {
    throw StateError(
      'GeekPlayerAudioHandler has not been initialised yet. '
      'Make sure `await AudioService.init(...)` ran before `runApp` '
      'and that the result was passed to `setAudioHandlerInstance(...)`.',
    );
  }
  return handler;
}

/// Type alias used to expose the handler as `AudioHandler` for callers
/// that only need the base interface (e.g. for testing).
@Riverpod(keepAlive: true)
AudioHandler audioHandlerInterface(Ref ref) => ref.watch(audioHandlerProvider);

GeekPlayerAudioHandler? _instance;

/// Called once from `main.dart` right after `AudioService.init` returns
/// the handler. Tests may also call this with a fake to seed the
/// provider before reading it.
void setAudioHandlerInstance(GeekPlayerAudioHandler handler) {
  _instance = handler;
}

/// For tests that want to reset the singleton between cases.
void resetAudioHandlerInstance() {
  _instance = null;
}
