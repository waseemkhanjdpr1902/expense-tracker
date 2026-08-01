import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/core/search_text.dart';
import 'package:xpense_traker/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    Future<void> add(String? desc, {String? counterparty, RecordType? type}) =>
        db.into(db.records).insert(RecordsCompanion.insert(
              amountMinor: 100000,
              type: type ?? RecordType.expense,
              occurredAt: DateTime(2026, 7, 1),
              description: Value(desc),
              counterparty: Value(counterparty),
            ));

    await add('Weekly grocery run');
    await add('Online course — Flutter advanced');
    await add('Project: Bakery POS App — Advance — 30%',
        type: RecordType.income);
    await add(null, counterparty: 'Bilal Ahmed', type: RecordType.loanGiven);
    await add('100_000 milestone');
  });

  tearDown(() => db.close());

  Future<List<RecordRow>> search(String q) =>
      db.watchRecords(query: q).first;

  group('instr() search has no pattern language', () {
    test('"30%" matches only the row containing that literal text', () async {
      final hits = await search('30%');
      expect(hits, hasLength(1));
      expect(hits.single.description, contains('30%'));
    });

    test('a bare "%" matches only literal percent signs, not everything',
        () async {
      // Under LIKE '%…%' this would match all 5 rows. As a literal it matches
      // exactly the one row whose text contains a '%'.
      final hits = await search('%');
      expect(hits, hasLength(1));
      expect(hits.single.description, contains('30%'));
    });

    test('a bare "_" matches nothing — it is not a single-char wildcard',
        () async {
      // '_' would match every row under LIKE; here it only matches literal '_'.
      final hits = await search('_');
      expect(hits, hasLength(1));
      expect(hits.single.description, '100_000 milestone');
    });

    test('backslash is literal, not an escape character', () async {
      expect(await search(r'\'), isEmpty);
      expect(await search(r'\%'), isEmpty);
    });
  });

  group('matching', () {
    test('is case-insensitive', () async {
      expect(await search('FLUTTER'), hasLength(1));
      expect(await search('flutter'), hasLength(1));
    });

    test('matches counterparty as well as description', () async {
      final hits = await search('bilal');
      expect(hits, hasLength(1));
      expect(hits.single.counterparty, 'Bilal Ahmed');
    });

    test('handles non-ASCII (em dash) through instr', () async {
      expect((await search('—')).length, greaterThanOrEqualTo(2));
    });

    test('never matches the type enum column', () async {
      // 'expense' is the stored enum text for 4 rows but appears in no
      // description, so a search for it must return nothing.
      expect(await search('expense'), isEmpty);
    });

    test('composes with other filters', () async {
      final hits = await db
          .watchRecords(query: 'a', typesIn: {RecordType.income}).first;
      expect(hits, hasLength(1));
      expect(hits.single.type, RecordType.income);
    });
  });

  group('normalizeQuery', () {
    test('blank and whitespace-only become null', () {
      expect(normalizeQuery(null), isNull);
      expect(normalizeQuery(''), isNull);
      expect(normalizeQuery('   '), isNull);
    });

    test('trims and collapses internal whitespace to one key', () {
      expect(normalizeQuery('  gro '), 'gro');
      expect(normalizeQuery('weekly   grocery'), 'weekly grocery');
    });
  });
}
