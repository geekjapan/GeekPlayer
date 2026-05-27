import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Imports that `core/errors/` MUST NOT depend on. `core/errors/` is a leaf
/// module; reversing the arrow creates an import cycle and undermines the
/// "every other layer may depend on core/errors" property.
const _forbiddenPrefixes = <String>[
  'package:geekplayer/core/network/',
  'package:geekplayer/core/storage/',
  'package:geekplayer/core/media/',
  'package:geekplayer/core/novel/',
  'package:geekplayer/core/consent/',
  'package:geekplayer/core/di/',
  'package:geekplayer/core/theme/',
  'package:geekplayer/features/',
  // Relative variants of the same imports.
  '../../network/',
  '../../storage/',
  '../../media/',
  '../../novel/',
  '../../consent/',
  '../../di/',
  '../../theme/',
  '../../../features/',
];

void main() {
  test('core/errors/ depends only on Flutter SDK, logger, intl, riverpod', () {
    final errorsDir = Directory('lib/core/errors');
    expect(
      errorsDir.existsSync(),
      isTrue,
      reason: 'lib/core/errors/ must exist (run from app/ directory)',
    );

    final violations = <String>[];
    for (final entity in errorsDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      // Generated files (`*.g.dart`) reuse imports from their sources; check
      // them too so a forbidden import in the source is caught here.
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
        for (final forbidden in _forbiddenPrefixes) {
          if (line.contains(forbidden)) {
            violations.add('${entity.path}:${i + 1}: $line');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'core/errors/ must not import from other core/* modules or features/*. '
          'Offending imports:\n${violations.join('\n')}',
    );
  });
}
