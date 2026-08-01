import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/core/hero.dart';

void main() {
  const id = 'a1b2c3';

  group('HeroTags', () {
    test('the same record in two lists gets two distinct tags', () {
      // Home and Records are adjacent PageView children of ONE route, so a
      // record present in both would otherwise collide and assert.
      expect(HeroTags.record('home', id),
          isNot(equals(HeroTags.record('records', id))));
      expect(HeroTags.record('search', id),
          isNot(equals(HeroTags.record('records', id))));
    });

    test('different records in the same list get different tags', () {
      expect(HeroTags.record('records', 'one'),
          isNot(equals(HeroTags.record('records', 'two'))));
    });

    test('the same record in the same list is stable across calls', () {
      expect(HeroTags.record('home', id), equals(HeroTags.record('home', id)));
    });

    test('a missing scope yields null — no Hero rather than a crash', () {
      expect(HeroTags.record(null, id), isNull);
      expect(HeroTags.project(null, id), isNull);
    });

    test('records and projects never collide, even on a shared id', () {
      expect(HeroTags.record('home', id),
          isNot(equals(HeroTags.project('home', id))));
    });
  });
}
