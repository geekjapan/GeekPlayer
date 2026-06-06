import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/settings/domain/setting_keys.dart';

/// Spec `settings-persistence` Requirement "Setting keys are namespaced
/// and stable" — every key MUST match `^[a-z][a-z_]*(\.[a-z][a-z_]*)+$`.
void main() {
  final RegExp keyRegex = RegExp(r'^[a-z][a-z_]*(\.[a-z][a-z_]*)+$');

  test('SettingKeys.all is non-empty', () {
    expect(SettingKeys.all, isNotEmpty);
  });

  test('every key matches the dotted-namespace regex', () {
    for (final String key in SettingKeys.all) {
      expect(
        keyRegex.hasMatch(key),
        isTrue,
        reason: '"$key" does not match $keyRegex',
      );
    }
  });

  test('keys are unique', () {
    expect(SettingKeys.all.toSet().length, SettingKeys.all.length);
  });

  test('all spec fields are represented (15)', () {
    expect(SettingKeys.all.length, 15);
  });
}
