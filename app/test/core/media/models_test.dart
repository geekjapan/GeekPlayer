import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/core/media/models.dart';

void main() {
  group('MediaSpeed', () {
    test('accepts positive finite values', () {
      expect(() => MediaSpeed(0.5), returnsNormally);
      expect(MediaSpeed(1.0).value, 1.0);
      expect(MediaSpeed.normal.value, 1.0);
    });

    test('rejects zero', () {
      expect(() => MediaSpeed(0), throwsArgumentError);
    });

    test('rejects negative values', () {
      expect(() => MediaSpeed(-1.0), throwsArgumentError);
    });

    test('rejects NaN and infinity', () {
      expect(() => MediaSpeed(double.nan), throwsArgumentError);
      expect(() => MediaSpeed(double.infinity), throwsArgumentError);
    });

    test('equality is value-based', () {
      expect(MediaSpeed(1.5), MediaSpeed(1.5));
      expect(MediaSpeed(1.5).hashCode, MediaSpeed(1.5).hashCode);
      expect(MediaSpeed(1.5), isNot(MediaSpeed(2.0)));
    });

    test('presets contains the 7 spec values in order', () {
      expect(
        MediaSpeed.presets.map((MediaSpeed s) => s.value).toList(),
        <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
      );
    });
  });

  group('MediaPosition', () {
    test('zero constant', () {
      expect(MediaPosition.zero.position, Duration.zero);
      expect(MediaPosition.zero.bufferEnd, Duration.zero);
    });

    test('equality and hash', () {
      const MediaPosition a = MediaPosition(
        position: Duration(seconds: 1),
        bufferEnd: Duration(seconds: 5),
      );
      const MediaPosition b = MediaPosition(
        position: Duration(seconds: 1),
        bufferEnd: Duration(seconds: 5),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith updates only the named fields', () {
      const MediaPosition original = MediaPosition(
        position: Duration(seconds: 10),
      );
      final MediaPosition updated = original.copyWith(
        position: const Duration(seconds: 20),
      );
      expect(updated.position, const Duration(seconds: 20));
      expect(updated.bufferEnd, original.bufferEnd);
    });
  });

  group('MediaPlayState', () {
    test('idle/loading/playing/paused/ended are distinct', () {
      const MediaPlayState idle = MediaPlayState.idle();
      const MediaPlayState loading = MediaPlayState.loading();
      const MediaPlayState playing = MediaPlayState.playing();
      const MediaPlayState paused = MediaPlayState.paused();
      const MediaPlayState ended = MediaPlayState.ended();
      expect(idle.isIdle, isTrue);
      expect(loading.isLoading, isTrue);
      expect(playing.isPlaying, isTrue);
      expect(paused.isPaused, isTrue);
      expect(ended.isEnded, isTrue);
    });

    test('equality groups by variant', () {
      expect(const MediaPlayState.playing(), const MediaPlayState.playing());
      expect(
        const MediaPlayState.playing(),
        isNot(const MediaPlayState.paused()),
      );
    });

    test('exhaustive switch compiles and works', () {
      String describe(MediaPlayState s) {
        return switch (s) {
          _ when s.isIdle => 'idle',
          _ when s.isLoading => 'loading',
          _ when s.isPlaying => 'playing',
          _ when s.isPaused => 'paused',
          _ when s.isEnded => 'ended',
          _ => 'unknown',
        };
      }

      expect(describe(const MediaPlayState.idle()), 'idle');
      expect(describe(const MediaPlayState.ended()), 'ended');
    });
  });

  test('kEndOfPlaybackThreshold is 5 seconds', () {
    expect(kEndOfPlaybackThreshold, const Duration(seconds: 5));
  });
}
