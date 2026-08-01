import 'package:drift/drift.dart';

import 'database.dart';

/// Development-only demo data.
///
/// Fills the database with ~6 months of realistic activity covering **every**
/// record type, categories, loans in both directions (outstanding + settled),
/// and projects with payment timelines. Project payments go through
/// [AppDatabase.addProjectPayment] so the payment ↔ income-record invariant is
/// exercised exactly as it is in production.
///
/// Amounts are in minor units (×100), sized for PKR — the default currency.
/// Everything is deterministic: no `Random`, so re-seeding gives the same set.
///
/// Wired to Settings → Developer → "Load demo data", which is only built in
/// debug mode. Never call this from a release path.
class DevSeed {
  const DevSeed._();

  /// Wipes all existing data, then inserts the demo set.
  /// Returns a short summary for the confirmation snackbar.
  static Future<String> load(AppDatabase db) async {
    await clear(db);

    final now = DateTime.now();
    final catIds = await _seedCategories(db);

    var recordCount = 0;
    await db.transaction(() async {
      recordCount += await _seedIncome(db, now, catIds);
      recordCount += await _seedExpenses(db, now, catIds);
      recordCount += await _seedRecentDays(db, now, catIds);
      recordCount += await _seedLoans(db, now, catIds);
    });

    final payments = await _seedProjects(db, now, catIds);

    // Project payments each create a mirrored income record.
    return '${recordCount + payments} records · ${catIds.length} categories · '
        '3 projects';
  }

  /// Removes every row the app owns. Used before a re-seed.
  static Future<void> clear(AppDatabase db) async {
    await db.transaction(() async {
      await db.delete(db.records).go();
      await db.delete(db.projectPayments).go();
      await db.delete(db.projects).go();
      await db.delete(db.categories).go();
    });
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  static const _categoryNames = <String>[
    'Salary',
    'Freelance',
    'Groceries',
    'Rent',
    'Utilities',
    'Transport',
    'Dining',
    'Health',
    'Shopping',
    'Education',
  ];

  static Future<Map<String, String>> _seedCategories(AppDatabase db) async {
    final ids = <String, String>{};
    for (final name in _categoryNames) {
      final row = await db.addCategory(name);
      ids[name] = row.id;
    }
    return ids;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// A date [monthsAgo] months back from [now], on [day], at a fixed hour so
  /// ordering within a day is stable.
  static DateTime _at(DateTime now, int monthsAgo, int day, [int hour = 12]) {
    final target = DateTime(now.year, now.month - monthsAgo, 1);
    // Clamp the day to the length of that month (e.g. day 31 in February).
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    final d = day > lastDay ? lastDay : day;
    return DateTime(target.year, target.month, d, hour);
  }

  /// True when the generated date is still in the future (the current, partial
  /// month) — those rows are skipped so the ledger never contains future data.
  static bool _isFuture(DateTime d, DateTime now) => d.isAfter(now);

  static Future<int> _insert(
    AppDatabase db,
    DateTime now,
    DateTime when, {
    required int amountMinor,
    required RecordType type,
    String? description,
    String? categoryId,
    String? counterparty,
    DateTime? expectedReturnAt,
    bool returned = false,
    DateTime? returnedAt,
  }) async {
    if (_isFuture(when, now)) return 0;
    await db.into(db.records).insert(
          RecordsCompanion.insert(
            amountMinor: amountMinor,
            type: type,
            occurredAt: when,
            description: Value(description),
            categoryId: Value(categoryId),
            counterparty: Value(counterparty),
            expectedReturnAt: Value(expectedReturnAt),
            returned: Value(returned),
            returnedAt: Value(returnedAt),
          ),
        );
    return 1;
  }

  // ── Income ─────────────────────────────────────────────────────────────────

  static Future<int> _seedIncome(
      AppDatabase db, DateTime now, Map<String, String> cat) async {
    var n = 0;
    // Monthly salary, with a raise three months in.
    for (var m = 6; m >= 0; m--) {
      n += await _insert(
        db,
        now,
        _at(now, m, 1, 10),
        amountMinor: m >= 3 ? 18500000 : 21000000,
        type: RecordType.income,
        description: 'Monthly salary',
        categoryId: cat['Salary'],
      );
    }
    // Irregular freelance work.
    const freelance = <(int monthsAgo, int day, int amount, String what)>[
      (6, 14, 4500000, 'Landing page for Meraki Studio'),
      (5, 22, 2750000, 'Logo + brand sheet'),
      (4, 9, 6200000, 'E-commerce bug retainer'),
      (2, 17, 3800000, 'Flutter consulting — 8 hrs'),
      (1, 26, 5100000, 'API integration sprint'),
    ];
    for (final (m, d, amt, what) in freelance) {
      n += await _insert(
        db,
        now,
        _at(now, m, d, 16),
        amountMinor: amt,
        type: RecordType.income,
        description: what,
        categoryId: cat['Freelance'],
      );
    }
    return n;
  }

  // ── Expenses ───────────────────────────────────────────────────────────────

  /// Recurring monthly bills — same category and rough amount every month.
  static const _recurring =
      <(String category, int day, int amount, String label)>[
    ('Rent', 3, 8500000, 'Apartment rent'),
    ('Utilities', 8, 1450000, 'Electricity + gas'),
    ('Utilities', 9, 350000, 'Internet'),
    ('Transport', 5, 1200000, 'Fuel — monthly'),
  ];

  /// Day-to-day spending, cycled across months so each one looks different.
  static const _variable =
      <(String category, int day, int amount, String label)>[
    ('Groceries', 6, 920000, 'Weekly grocery run'),
    ('Dining', 11, 340000, 'Dinner at Kolachi'),
    ('Groceries', 13, 780000, 'Weekly grocery run'),
    ('Shopping', 16, 1850000, 'Winter jacket'),
    ('Groceries', 20, 860000, 'Weekly grocery run'),
    ('Health', 21, 650000, 'Pharmacy + checkup'),
    ('Dining', 24, 420000, 'Coffee & work session'),
    ('Groceries', 27, 910000, 'Weekly grocery run'),
    ('Education', 28, 1500000, 'Online course — Flutter advanced'),
    ('Transport', 29, 480000, 'Ride hailing'),
  ];

  static Future<int> _seedExpenses(
      AppDatabase db, DateTime now, Map<String, String> cat) async {
    var n = 0;
    for (var m = 6; m >= 0; m--) {
      for (final (category, day, amount, label) in _recurring) {
        n += await _insert(
          db,
          now,
          _at(now, m, day, 9),
          // Utilities drift a little month to month.
          amountMinor: category == 'Utilities'
              ? amount + (m.isEven ? 120000 : -80000)
              : amount,
          type: RecordType.expense,
          description: label,
          categoryId: cat[category],
        );
      }
      // Take a rotating slice of the variable list so months differ.
      final start = (6 - m) % 3;
      for (var i = start; i < _variable.length; i += 1) {
        if ((i + m) % 4 == 3) continue; // skip a few for natural variation
        final (category, day, amount, label) = _variable[i];
        n += await _insert(
          db,
          now,
          _at(now, m, day, 13),
          amountMinor: amount,
          type: RecordType.expense,
          description: label,
          categoryId: cat[category],
        );
      }
    }
    return n;
  }

  // ── Recent activity ────────────────────────────────────────────────────────

  /// Day-offset entries anchored to *today* rather than to a day-of-month, so
  /// there is always fresh activity in the last week and the current month is
  /// never empty — on the 1st, every day-of-month expense above is in the
  /// future and gets skipped.
  static const _recent =
      <(int daysAgo, String category, int amount, String label, bool isIncome)>[
    (0, 'Dining', 145000, 'Lunch', false),
    (0, 'Transport', 60000, 'Ride to office', false),
    (1, 'Groceries', 435000, 'Milk, eggs, bread', false),
    (2, 'Dining', 220000, 'Team coffee', false),
    (3, 'Freelance', 1250000, 'Bug-fix retainer — weekly', true),
    (4, 'Shopping', 690000, 'Phone case + charger', false),
    (5, 'Groceries', 780000, 'Weekly grocery run', false),
    (6, 'Health', 320000, 'Pharmacy', false),
  ];

  static Future<int> _seedRecentDays(
      AppDatabase db, DateTime now, Map<String, String> cat) async {
    var n = 0;
    for (final (daysAgo, category, amount, label, isIncome) in _recent) {
      final when = now.subtract(Duration(days: daysAgo, hours: 2));
      n += await _insert(
        db,
        now,
        when,
        amountMinor: amount,
        type: isIncome ? RecordType.income : RecordType.expense,
        description: label,
        categoryId: cat[category],
      );
    }
    return n;
  }

  // ── Loans (given + taken, settled + outstanding) ────────────────────────────

  static Future<int> _seedLoans(
      AppDatabase db, DateTime now, Map<String, String> cat) async {
    var n = 0;

    // Money lent out — two settled, two still outstanding.
    n += await _insert(db, now, _at(now, 5, 12),
        amountMinor: 2500000,
        type: RecordType.loanGiven,
        description: 'Lent for laptop repair',
        counterparty: 'Bilal Ahmed',
        expectedReturnAt: _at(now, 4, 12),
        returned: true,
        returnedAt: _at(now, 4, 10));
    n += await _insert(db, now, _at(now, 4, 3),
        amountMinor: 1200000,
        type: RecordType.loanGiven,
        description: 'Covered dinner bill',
        counterparty: 'Hina Raza',
        expectedReturnAt: _at(now, 3, 3),
        returned: true,
        returnedAt: _at(now, 3, 1));
    n += await _insert(db, now, _at(now, 3, 18),
        amountMinor: 7500000,
        type: RecordType.loanGiven,
        description: 'Short-term loan — moving costs',
        counterparty: 'Usman Tariq',
        expectedReturnAt: _at(now, 0, 18),
        categoryId: cat['Shopping']);
    n += await _insert(db, now, _at(now, 1, 7),
        amountMinor: 3000000,
        type: RecordType.loanGiven,
        description: 'Advance for shared trip',
        counterparty: 'Zara Khan',
        expectedReturnAt: _at(now, 0, 25));

    // Money borrowed — one settled, two still owed.
    n += await _insert(db, now, _at(now, 5, 25),
        amountMinor: 5000000,
        type: RecordType.loanTaken,
        description: 'Borrowed for medical bill',
        counterparty: 'Ayesha Siddiqui',
        expectedReturnAt: _at(now, 4, 25),
        returned: true,
        returnedAt: _at(now, 4, 20),
        categoryId: cat['Health']);
    n += await _insert(db, now, _at(now, 2, 14),
        amountMinor: 9500000,
        type: RecordType.loanTaken,
        description: 'Borrowed from Dad — bike down payment',
        counterparty: 'Father',
        expectedReturnAt: _at(now, 0, 14));
    n += await _insert(db, now, _at(now, 1, 19),
        amountMinor: 2200000,
        type: RecordType.loanTaken,
        description: 'Office lunch fund',
        counterparty: 'Hamza Sheikh',
        expectedReturnAt: _at(now, 0, 19),
        categoryId: cat['Dining']);

    return n;
  }

  // ── Projects (payments post as income automatically) ────────────────────────

  static Future<int> _seedProjects(
      AppDatabase db, DateTime now, Map<String, String> cat) async {
    var payments = 0;

    Future<void> project({
      required String name,
      required String description,
      required String? categoryId,
      required int totalMinor,
      required DateTime start,
      DateTime? end,
      DateTime? completedAt,
      required List<(DateTime paidOn, int amount, String note)> schedule,
    }) async {
      final id = await _newProjectId(db,
          name: name,
          description: description,
          categoryId: categoryId,
          totalMinor: totalMinor,
          start: start,
          end: end,
          completedAt: completedAt);
      for (final (paidOn, amount, note) in schedule) {
        if (_isFuture(paidOn, now)) continue;
        await db.addProjectPayment(
          projectId: id,
          projectName: name,
          projectCategoryId: categoryId,
          amountMinor: amount,
          note: note,
          paidAt: paidOn,
        );
        payments++;
      }
    }

    // 1. Finished — fully paid AND explicitly marked complete, so the
    // Projects status filter has something to exclude by default.
    await project(
      name: 'Bakery POS App',
      description: 'Point-of-sale Flutter app for a local bakery chain.',
      categoryId: cat['Freelance'],
      totalMinor: 30000000,
      start: _at(now, 6, 5),
      end: _at(now, 3, 28),
      completedAt: _at(now, 3, 28),
      schedule: [
        (_at(now, 6, 5, 11), 9000000, 'Advance — 30%'),
        (_at(now, 5, 2, 11), 9000000, 'Milestone 1 — catalogue'),
        (_at(now, 4, 8, 11), 6000000, 'Milestone 2 — billing'),
        (_at(now, 3, 28, 11), 6000000, 'Final delivery'),
      ],
    );

    // 2. In progress — partially paid, remaining balance visible.
    await project(
      name: 'Clinic Booking Portal',
      description: 'Web portal + admin dashboard for appointment booking.',
      categoryId: cat['Freelance'],
      totalMinor: 45000000,
      start: _at(now, 3, 10),
      end: _at(now, 0, 30),
      schedule: [
        (_at(now, 3, 10, 15), 13500000, 'Advance — 30%'),
        (_at(now, 2, 12, 15), 9000000, 'Milestone 1 — auth + profiles'),
        (_at(now, 1, 15, 15), 9000000, 'Milestone 2 — scheduling'),
      ],
    );

    // 3. Just started — advance only.
    await project(
      name: 'Logistics Tracker',
      description: 'Fleet tracking dashboard with live vehicle positions.',
      categoryId: cat['Salary'],
      totalMinor: 60000000,
      start: _at(now, 1, 20),
      end: null,
      schedule: [
        (_at(now, 1, 20, 14), 15000000, 'Advance — 25%'),
      ],
    );

    return payments;
  }

  static Future<String> _newProjectId(
    AppDatabase db, {
    required String name,
    required String description,
    required String? categoryId,
    required int totalMinor,
    required DateTime start,
    DateTime? end,
    DateTime? completedAt,
  }) async {
    await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            name: name,
            description: Value(description),
            categoryId: Value(categoryId),
            totalAmountMinor: totalMinor,
            startDate: start,
            endDate: Value(end),
            completedAt: Value(completedAt),
          ),
        );
    final row = await (db.select(db.projects)
          ..where((p) => p.name.equals(name))
          ..limit(1))
        .getSingle();
    return row.id;
  }
}
