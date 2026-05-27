import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/media_session.dart';
import 'package:geekplayer/core/media/models.dart';

void main() {
  group('VideoSession (streams-only test seam)', () {
    late StreamController<Duration> position;
    late StreamController<Duration> buffer;
    late StreamController<Duration> duration;
    late StreamController<bool> playing;
    late StreamController<bool> completed;
    late VideoSession session;

    setUp(() {
      position = StreamController<Duration>.broadcast();
      buffer = StreamController<Duration>.broadcast();
      duration = StreamController<Duration>.broadcast();
      playing = StreamController<bool>.broadcast();
      completed = StreamController<bool>.broadcast();
      session = VideoSession.fromStreams(
        position: position.stream,
        buffer: buffer.stream,
        duration: duration.stream,
        playing: playing.stream,
        completed: completed.stream,
      );
    });

    tearDown(() async {
      await session.dispose();
      await position.close();
      await buffer.close();
      await duration.close();
      await playing.close();
      await completed.close();
    });

    test(
      'positionStream emits transformed MediaPosition on engine event',
      () async {
        final Future<MediaPosition> first = session.positionStream.first;
        position.add(const Duration(seconds: 12));
        final MediaPosition p = await first;
        expect(p.position, const Duration(seconds: 12));
      },
    );

    test(
      'playStateStream emits playing when engine reports playing=true',
      () async {
        final Future<MediaPlayState> first = session.playStateStream.first;
        playing.add(true);
        final MediaPlayState s = await first;
        expect(s, const MediaPlayState.playing());
      },
    );

    test(
      'playStateStream emits paused when engine reports playing=false',
      () async {
        final Future<MediaPlayState> first = session.playStateStream.first;
        playing.add(false);
        final MediaPlayState s = await first;
        expect(s, const MediaPlayState.paused());
      },
    );

    test(
      'completed=true overrides to ended even when playing was true',
      () async {
        final List<MediaPlayState> states = <MediaPlayState>[];
        final StreamSubscription<MediaPlayState> sub = session.playStateStream
            .listen(states.add);
        playing.add(true);
        completed.add(true);
        // Allow microtasks to flush.
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(states.last, const MediaPlayState.ended());
      },
    );

    test(
      'durationStream emits null for Duration.zero, value otherwise',
      () async {
        final List<Duration?> values = <Duration?>[];
        final StreamSubscription<Duration?> sub = session.durationStream.listen(
          values.add,
        );
        duration.add(Duration.zero);
        duration.add(const Duration(minutes: 5));
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(values, <Duration?>[null, const Duration(minutes: 5)]);
      },
    );

    test('dispose() completes streams and subsequent commands throw', () async {
      await session.dispose();
      // Streams should be closed; reading .first after close yields an
      // error future. We simply confirm a command throws StateError.
      expect(session.play(), throwsA(isA<StateError>()));
    });

    test('dispose() is idempotent', () async {
      await session.dispose();
      await expectLater(session.dispose(), completes);
    });

    test(
      'setSpeed updates speed getter even with no underlying player',
      () async {
        await session.setSpeed(MediaSpeed.x1_5);
        expect(session.speed.value, 1.5);
      },
    );
  });
}
