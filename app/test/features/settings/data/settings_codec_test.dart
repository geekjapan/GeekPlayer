import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/settings/data/settings_codec.dart';
import 'package:geekplayer/features/settings/domain/novel_writing_mode.dart';

void main() {
  group('BoolCodec', () {
    const SettingCodec<bool> c = BoolCodec();

    test('roundtrips true and false', () {
      expect(c.encode(true), 'true');
      expect(c.encode(false), 'false');
      expect(c.decode('true'), true);
      expect(c.decode('false'), false);
    });

    test('decoding garbage throws FormatException', () {
      expect(() => c.decode('yes'), throwsFormatException);
      expect(() => c.decode(''), throwsFormatException);
      expect(() => c.decode('TRUE'), throwsFormatException);
    });
  });

  group('IntCodec', () {
    const SettingCodec<int> c = IntCodec();

    test('roundtrips', () {
      expect(c.decode(c.encode(42)), 42);
      expect(c.decode(c.encode(-1)), -1);
      expect(c.decode(c.encode(0)), 0);
    });

    test('garbage throws FormatException', () {
      expect(() => c.decode('3.14'), throwsFormatException);
      expect(() => c.decode('abc'), throwsFormatException);
    });
  });

  group('DoubleCodec', () {
    const SettingCodec<double> c = DoubleCodec();

    test('roundtrips', () {
      expect(c.decode(c.encode(1.7)), closeTo(1.7, 1e-9));
      expect(c.decode(c.encode(-2.5)), closeTo(-2.5, 1e-9));
    });

    test('garbage throws FormatException', () {
      expect(() => c.decode('not-a-number'), throwsFormatException);
    });
  });

  group('NullableIntCodec', () {
    const SettingCodec<int?> c = NullableIntCodec();

    test('encodes null distinctly', () {
      expect(c.encode(null), 'null');
      expect(c.decode('null'), isNull);
    });

    test('roundtrips ordinary ints', () {
      expect(c.decode(c.encode(7)), 7);
      expect(c.decode(c.encode(0)), 0);
    });

    test('garbage throws FormatException', () {
      expect(() => c.decode('NULL'), throwsFormatException);
      expect(() => c.decode('abc'), throwsFormatException);
    });
  });

  group('StringCodec', () {
    const SettingCodec<String> c = StringCodec();

    test('roundtrips arbitrary strings', () {
      expect(c.decode(c.encode('noto-serif-jp')), 'noto-serif-jp');
      expect(c.decode(c.encode('')), '');
    });
  });

  group('EnumCodec<ThemeMode>', () {
    const SettingCodec<ThemeMode> c = EnumCodec<ThemeMode>(ThemeMode.values);

    test('roundtrips every variant', () {
      for (final ThemeMode v in ThemeMode.values) {
        expect(c.decode(c.encode(v)), v);
      }
    });

    test('unknown name throws FormatException', () {
      expect(() => c.decode('twilight'), throwsFormatException);
    });
  });

  group('EnumCodec<NovelWritingMode>', () {
    const SettingCodec<NovelWritingMode> c = EnumCodec<NovelWritingMode>(
      NovelWritingMode.values,
    );

    test('roundtrips both variants', () {
      expect(
        c.decode(c.encode(NovelWritingMode.vertical)),
        NovelWritingMode.vertical,
      );
      expect(
        c.decode(c.encode(NovelWritingMode.horizontal)),
        NovelWritingMode.horizontal,
      );
    });
  });
}
