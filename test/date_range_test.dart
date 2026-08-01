import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/core/date_range.dart';

void main() {
  final now = DateTime(2026, 8, 1, 12);

  group('DateRangeFilter.all', () {
    test('resolveOrNull returns null — no date bound reaches the query', () {
      expect(DateRangeFilter.all.resolveOrNull(now), isNull);
    });

    test('resolve still returns a very wide window as a safety net', () {
      final r = DateRangeFilter.all.resolve(now);
      expect(r.start.isBefore(DateTime(1971)), isTrue);
      expect(r.end.isAfter(DateTime(2100)), isTrue);
    });

    test('isAllTime identifies it', () {
      expect(isAllTime(DateRangeFilter.all), isTrue);
      expect(isAllTime(DateRangeFilter.month), isFalse);
    });

    test('equal and hash-equal — required for Riverpod family keys', () {
      expect(DateRangeFilter.all, equals(DateRangeFilter.all));
      expect(DateRangeFilter.all.hashCode,
          equals(DateRangeFilter.all.hashCode));
      expect(DateRangeFilter.all == DateRangeFilter.month, isFalse);
    });
  });

  group('bounded filters', () {
    test('resolveOrNull returns a real window', () {
      expect(DateRangeFilter.month.resolveOrNull(now), isNotNull);
      expect(DateRangeFilter.week.resolveOrNull(now), isNotNull);
      expect(DateRangeFilter.calendarYear(2025).resolveOrNull(now), isNotNull);
    });

    test('rolling month spans 30 days back from now', () {
      final r = DateRangeFilter.month.resolveOrNull(now)!;
      expect(now.difference(r.start).inDays, 30);
      expect(r.end, now);
    });
  });
}
