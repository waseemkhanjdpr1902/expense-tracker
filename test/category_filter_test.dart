import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/core/date_range.dart';
import 'package:xpense_traker/data/database.dart';
import 'package:xpense_traker/data/providers.dart';

void main() {
  group('multi-category filtering', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> record(String categoryId, int amountMinor) =>
        db.into(db.records).insert(
              RecordsCompanion.insert(
                amountMinor: amountMinor,
                type: RecordType.expense,
                occurredAt: DateTime(2026, 5, 1),
                categoryId: Value(categoryId),
              ),
            );

    setUp(() async {
      await record('food', 1000);
      await record('rent', 2000);
      await record('fuel', 3000);
    });

    test('several categories return the union of their records', () async {
      final rows =
          await db.watchRecords(categoryIds: ['food', 'fuel']).first;
      expect(rows.map((r) => r.amountMinor).toSet(), {1000, 3000});
    });

    test('one category still works', () async {
      final rows = await db.watchRecords(categoryIds: ['rent']).first;
      expect(rows.single.amountMinor, 2000);
    });

    test('an empty selection means no filter, not no results', () async {
      // "All" in the UI is the empty selection rather than a sentinel, so this
      // is the difference between showing everything and showing nothing.
      expect((await db.watchRecords(categoryIds: const []).first).length, 3);
      expect((await db.watchRecords().first).length, 3);
    });
  });

  group('family keys stay equal regardless of tap order', () {
    // The trap this guards: a Set's iteration order is insertion order, and
    // Dart's List == is identity. Without canonicalising, picking Food then
    // Fuel would build a different key from Fuel then Food — same filter, two
    // cached streams, and a fresh AsyncLoading on every reorder.
    test('categoryKey sorts, so selection order does not leak into the key',
        () {
      expect(categoryKey({'fuel', 'food'}), ['food', 'fuel']);
      expect(categoryKey({'food', 'fuel'}), categoryKey({'fuel', 'food'}));
    });

    test('RecordsQuery equality and hashCode ignore selection order', () {
      final a = RecordsQuery(
        type: RecordsFilter.all,
        range: DateRangeFilter.month,
        categoryIds: categoryKey({'food', 'fuel'}),
      );
      final b = RecordsQuery(
        type: RecordsFilter.all,
        range: DateRangeFilter.month,
        categoryIds: categoryKey({'fuel', 'food'}),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different selections are different keys', () {
      final a = RecordsQuery(
        type: RecordsFilter.all,
        range: DateRangeFilter.month,
        categoryIds: categoryKey({'food'}),
      );
      final b = RecordsQuery(
        type: RecordsFilter.all,
        range: DateRangeFilter.month,
        categoryIds: categoryKey({'food', 'fuel'}),
      );
      expect(a, isNot(equals(b)));
    });

    test('LoansQuery equality ignores selection order too', () {
      final a = LoansQuery(
        returned: false,
        type: LoanTypeFilter.all,
        range: DateRangeFilter.all,
        categoryIds: categoryKey({'a', 'b', 'c'}),
      );
      final b = LoansQuery(
        returned: false,
        type: LoanTypeFilter.all,
        range: DateRangeFilter.all,
        categoryIds: categoryKey({'c', 'a', 'b'}),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
