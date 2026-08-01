import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the iconography rule stated in `lib/core/icons.dart`:
///
/// > Every icon is `Icons.*_rounded`. The only exception is `Icons.*_outlined`,
/// > used exclusively as the unselected half of a selected/unselected pair.
///
/// Before this existed the app had 65 distinct icons across three Material
/// families — `label` alone appeared as `label_outline`, `label_outlined` and
/// `label_outline_rounded`. Mixed families are what make an interface read as
/// assembled rather than designed.
void main() {
  test('every Icons.* reference is _rounded or _outlined', () {
    final offenders = <String>[];
    // Lookbehind so `AppIcons.foo` is not matched as `Icons.foo`.
    final pattern = RegExp(r'(?<![A-Za-z])Icons\.([a-zA-Z0-9_]+)');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          final name = m.group(1)!;
          if (name.endsWith('_rounded') || name.endsWith('_outlined')) continue;
          offenders.add('${entity.path}:${i + 1}  Icons.$name');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These icons are not from the rounded family:\n'
          '${offenders.join('\n')}\n\n'
          'Use Icons.*_rounded (or AppIcons.*). Reserve _outlined for the '
          'unselected half of a selected/unselected pair.',
    );
  });

  test('_outlined is only used for selected/unselected pairs', () {
    // Today that is exclusively the nav bar. If this list grows, the pairing
    // should be a deliberate decision rather than a leftover.
    const allowed = {'lib/shell/home_shell.dart', 'lib/core/icons.dart'};
    final offenders = <String>[];
    final pattern = RegExp(r'(?<![A-Za-z])Icons\.([a-zA-Z0-9_]+_outlined)\b');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowed.contains(entity.path.replaceAll(r'\', '/'))) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          offenders.add('${entity.path}:${i + 1}  Icons.${m.group(1)}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: '_outlined outside a selected/unselected pair:\n'
            '${offenders.join('\n')}');
  });
}
