import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec `english-localization` Requirement "ARB keys have Japanese and
/// English parity": every translatable key in app_ja.arb must have a
/// counterpart in app_en.arb and vice versa. `@`-metadata entries and the
/// `@@locale` marker are excluded.
Set<String> _translatableKeys(String path) {
  final Map<String, dynamic> arb =
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return arb.keys.where((String k) => !k.startsWith('@')).toSet();
}

void main() {
  test('app_ja.arb and app_en.arb have identical translatable keys', () {
    final Set<String> ja = _translatableKeys('lib/l10n/app_ja.arb');
    final Set<String> en = _translatableKeys('lib/l10n/app_en.arb');

    expect(
      ja.difference(en),
      isEmpty,
      reason: 'Keys present in ja but missing in en',
    );
    expect(
      en.difference(ja),
      isEmpty,
      reason: 'Keys present in en but missing in ja',
    );
    expect(ja, isNotEmpty);
  });

  test('no translatable value is empty in either locale', () {
    for (final String path in <String>[
      'lib/l10n/app_ja.arb',
      'lib/l10n/app_en.arb',
    ]) {
      final Map<String, dynamic> arb =
          json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
      for (final MapEntry<String, dynamic> e in arb.entries) {
        if (e.key.startsWith('@')) continue;
        expect(
          (e.value as String).trim(),
          isNotEmpty,
          reason: '$path key ${e.key} is empty',
        );
      }
    }
  });
}
