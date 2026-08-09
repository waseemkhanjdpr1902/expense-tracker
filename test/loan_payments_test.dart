// drift exports SQL `isNull`/`isNotNull` expressions that collide with the
// matcher package's identically-named matchers.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/data/database.dart';

/// Money in these tests is written in minor units: 500000 == 5,000.00.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  var seq = 0;

  /// Ids are explicit rather than "the newest row": `createdAt` defaults to
  /// `DateTime.now()`, so two loans inserted in the same millisecond tie and
  /// the newest-first lookup returns an arbitrary one of them.
  Future<RecordRow> insertLoan({
    required RecordType type,
    int amountMinor = 500000,
  }) async {
    final id = 'loan-${seq++}';
    await db.into(db.records).insert(
          RecordsCompanion.insert(
            id: Value(id),
            amountMinor: amountMinor,
            type: type,
            occurredAt: DateTime(2026, 3, 1),
            counterparty: const Value('Zara Khan'),
          ),
        );
    return (db.select(db.records)..where((r) => r.id.equals(id))).getSingle();
  }

  Future<DashboardStats> stats() => db.watchStats().first;

  group('instalments reduce what is outstanding', () {
    test('the scenario this feature exists for: 5,000 lent, repaid 2/2/1',
        () async {
      final loan = await insertLoan(type: RecordType.loanGiven);
      expect((await stats()).outstandingLoanMinor, 500000);

      for (final amount in [200000, 200000, 100000]) {
        await db.addLoanPayment(
          loanId: loan.id,
          amountMinor: amount,
          paidAt: DateTime(2026, 4, 1),
        );
      }

      final s = await stats();
      expect(s.outstandingLoanMinor, 0, reason: 'fully repaid across three');
      expect(s.outstandingLoanCount, 0);
    });

    test('a partial repayment leaves the remainder outstanding', () async {
      final loan = await insertLoan(type: RecordType.loanGiven);
      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 200000,
        paidAt: DateTime(2026, 4, 1),
      );

      final s = await stats();
      expect(s.outstandingLoanMinor, 300000);
      expect(s.outstandingLoanCount, 1,
          reason: 'still counts as one open loan');
    });

    test('overpayment clamps at zero rather than going negative', () async {
      // Negative debt would quietly inflate the balance.
      final loan = await insertLoan(type: RecordType.loanGiven);
      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 700000,
        paidAt: DateTime(2026, 4, 1),
      );
      expect((await stats()).outstandingLoanMinor, 0);
    });
  });

  group('auto-settle', () {
    test('a loan settles itself once repayments cover the principal', () async {
      final loan = await insertLoan(type: RecordType.loanGiven);
      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 500000,
        paidAt: DateTime(2026, 4, 1),
      );

      final after = await db.watchLoan(loan.id).first;
      expect(after!.returned, isTrue);
      expect(after.returnedAt, isNotNull);
    });

    test('it stays open while anything is still owed', () async {
      final loan = await insertLoan(type: RecordType.loanGiven);
      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 499999,
        paidAt: DateTime(2026, 4, 1),
      );
      expect((await db.watchLoan(loan.id).first)!.returned, isFalse);
    });

    test('deleting a repayment re-opens a settled loan', () async {
      // Otherwise a mistyped final instalment would close a loan that is
      // still owed, and correcting it would leave it wrongly settled.
      final loan = await insertLoan(type: RecordType.loanGiven);
      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 500000,
        paidAt: DateTime(2026, 4, 1),
      );
      expect((await db.watchLoan(loan.id).first)!.returned, isTrue);

      final pay = (await db.watchLoanPayments(loan.id).first).single;
      await db.deleteLoanPayment(pay.id);

      final after = await db.watchLoan(loan.id).first;
      expect(after!.returned, isFalse);
      expect(after.returnedAt, isNull);
      expect((await stats()).outstandingLoanMinor, 500000);
    });

    test('settling early is honoured and not undone', () async {
      // You forgave the rest. The loan is closed even though the numbers
      // don't add up to the principal.
      final loan = await insertLoan(type: RecordType.loanGiven);
      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 100000,
        paidAt: DateTime(2026, 4, 1),
      );
      await db.markLoanReturned(loan.id, returned: true);

      expect((await db.watchLoan(loan.id).first)!.returned, isTrue);
      expect((await stats()).outstandingLoanMinor, 0,
          reason: 'a settled loan is not outstanding at any amount');
    });
  });

  group('balance direction', () {
    test('lending lowers the balance, and repayment brings it back', () async {
      final loan = await insertLoan(type: RecordType.loanGiven);
      expect((await stats()).availableBalance, -500000);

      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 500000,
        paidAt: DateTime(2026, 4, 1),
      );
      expect((await stats()).availableBalance, 0);
    });

    test('borrowing raises the balance, and repaying it lowers it', () async {
      // The sign this release fixes. Borrowed cash is in your pocket, so it
      // adds; paying it back spends it, so the balance falls. The old formula
      // subtracted borrowed money, which meant repaying a debt made you look
      // richer.
      final loan = await insertLoan(type: RecordType.loanTaken);
      expect((await stats()).availableBalance, 500000);

      await db.addLoanPayment(
        loanId: loan.id,
        amountMinor: 200000,
        paidAt: DateTime(2026, 4, 1),
      );
      expect((await stats()).availableBalance, 300000);
    });
  });

  test('repayments are not mirrored into records', () async {
    // Unlike project payments. Your own money coming back is not new income —
    // minting a record would double-count it against the balance and inflate
    // lifetime income.
    final loan = await insertLoan(type: RecordType.loanGiven);
    await db.addLoanPayment(
      loanId: loan.id,
      amountMinor: 200000,
      paidAt: DateTime(2026, 4, 1),
    );

    expect(await db.countRecords(), 1, reason: 'still just the loan itself');
    expect((await stats()).incomeMinor, 0);
  });

  test('instalments are scoped to their own loan', () async {
    final a = await insertLoan(type: RecordType.loanGiven);
    final b = await insertLoan(type: RecordType.loanGiven, amountMinor: 300000);

    await db.addLoanPayment(
      loanId: a.id,
      amountMinor: 200000,
      paidAt: DateTime(2026, 4, 1),
    );

    expect(await db.repaidTotal(a.id), 200000);
    expect(await db.repaidTotal(b.id), 0);
    expect((await stats()).outstandingLoanMinor, 300000 + 300000);
  });
}
