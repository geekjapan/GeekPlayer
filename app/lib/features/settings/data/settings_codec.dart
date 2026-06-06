import 'package:flutter/material.dart' show ThemeMode;

import '../domain/ai_upscale_backend_override.dart';
import '../domain/novel_writing_mode.dart';

/// Bidirectional string<->T encoder for an individual setting value.
///
/// Every concrete `SettingCodec` MUST treat `encode` as the inverse of
/// `decode`: `c.decode(c.encode(v))` MUST equal `v` for the type's
/// well-formed inputs. `decode` MUST throw [FormatException] on malformed
/// input — the repository layer catches the exception and falls back to
/// the per-field default (spec `settings-persistence` Requirement
/// "Repository hydrates AppSettings with defaults fallback").
abstract class SettingCodec<T> {
  const SettingCodec();

  String encode(T value);
  T decode(String raw);
}

class BoolCodec extends SettingCodec<bool> {
  const BoolCodec();

  @override
  String encode(bool value) => value ? 'true' : 'false';

  @override
  bool decode(String raw) {
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    throw FormatException('BoolCodec: not a bool literal', raw);
  }
}

class IntCodec extends SettingCodec<int> {
  const IntCodec();

  @override
  String encode(int value) => value.toString();

  @override
  int decode(String raw) {
    final int? v = int.tryParse(raw);
    if (v == null) {
      throw FormatException('IntCodec: not an integer', raw);
    }
    return v;
  }
}

class DoubleCodec extends SettingCodec<double> {
  const DoubleCodec();

  @override
  String encode(double value) => value.toString();

  @override
  double decode(String raw) {
    final double? v = double.tryParse(raw);
    if (v == null) {
      throw FormatException('DoubleCodec: not a double', raw);
    }
    return v;
  }
}

/// Encodes null distinctly from any other int value: the literal string
/// `'null'`. Used for `novelCacheCapMb` where `null` means "unlimited".
class NullableIntCodec extends SettingCodec<int?> {
  const NullableIntCodec();

  static const String _nullSentinel = 'null';

  @override
  String encode(int? value) {
    if (value == null) return _nullSentinel;
    return value.toString();
  }

  @override
  int? decode(String raw) {
    if (raw == _nullSentinel) return null;
    final int? v = int.tryParse(raw);
    if (v == null) {
      throw FormatException('NullableIntCodec: not an integer or null', raw);
    }
    return v;
  }
}

/// Pass-through codec for plain strings. Used by `novelFontFamily`.
class StringCodec extends SettingCodec<String> {
  const StringCodec();

  @override
  String encode(String value) => value;

  @override
  String decode(String raw) => raw;
}

/// Encodes Dart enums by their `.name` (lower-case identifier).
///
/// The constructor takes the enum's `values` list. Decoding searches
/// the list for a matching `.name` and throws [FormatException] when
/// nothing matches — a stronger guarantee than `byName` which raises
/// [ArgumentError].
class EnumCodec<E extends Enum> extends SettingCodec<E> {
  const EnumCodec(this._values);

  final List<E> _values;

  @override
  String encode(E value) => value.name;

  @override
  E decode(String raw) {
    for (final E v in _values) {
      if (v.name == raw) return v;
    }
    throw FormatException('EnumCodec<$E>: unknown name', raw);
  }
}

/// Convenience instances. These are stateless and may be shared.
const SettingCodec<bool> kBoolCodec = BoolCodec();
const SettingCodec<int> kIntCodec = IntCodec();
const SettingCodec<double> kDoubleCodec = DoubleCodec();
const SettingCodec<int?> kNullableIntCodec = NullableIntCodec();
const SettingCodec<String> kStringCodec = StringCodec();
const SettingCodec<ThemeMode> kThemeModeCodec = EnumCodec<ThemeMode>(
  ThemeMode.values,
);
const SettingCodec<NovelWritingMode> kNovelWritingModeCodec =
    EnumCodec<NovelWritingMode>(NovelWritingMode.values);
const SettingCodec<AiUpscaleBackendOverride> kAiUpscaleBackendOverrideCodec =
    EnumCodec<AiUpscaleBackendOverride>(AiUpscaleBackendOverride.values);
