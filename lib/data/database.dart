import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

const _uuid = Uuid();

enum RecordType { expense, income, loanGiven, loanTaken }

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RecordRow')
class Records extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get amountMinor => integer()();
  TextColumn get type => textEnum<RecordType>()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  TextColumn get counterparty => text().nullable()();
  DateTimeColumn get expectedReturnAt => dateTime().nullable()();
  BoolColumn get returned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get returnedAt => dateTime().nullable()();
  TextColumn get categoryId => text().nullable()();

  /// When set, this income record is the money side of a project payment
  /// (see [ProjectPayments]). Used to keep the two in sync on edit/delete.
  TextColumn get projectPaymentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DashboardStats {
  final int incomeMinor;
  final int expenseMinor;
  final int outstandingLoanMinor;
  final int outstandingBorrowedMinor;
  final int monthIncomeMinor;
  final int monthExpenseMinor;
  final int outstandingLoanCount;
  final int outstandingBorrowedCount;

  const DashboardStats({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.outstandingLoanMinor,
    required this.outstandingBorrowedMinor,
    required this.monthIncomeMinor,
    required this.monthExpenseMinor,
    required this.outstandingLoanCount,
    required this.outstandingBorrowedCount,
  });

  /// Cash you can actually spend right now.
  ///
  /// Money you **lent** is subtracted: it left your pocket and hasn't come
  /// back. Money you **borrowed** is added: it is sitting in your pocket, and
  /// you owe it — the debt is real but it is not a reduction in available cash.
  ///
  /// Borrowed money used to be subtracted here, which double-counted it: the
  /// cash was never credited on the way in, and then the liability was
  /// deducted on top. It stayed invisible while the number could only move
  /// once. Instalments make it obvious — every repayment you made would have
  /// *raised* your balance, which is backwards — so the sign is fixed here.
  int get availableBalance =>
      incomeMinor - expenseMinor - outstandingLoanMinor + outstandingBorrowedMinor;

  static const empty = DashboardStats(
    incomeMinor: 0,
    expenseMinor: 0,
    outstandingLoanMinor: 0,
    outstandingBorrowedMinor: 0,
    monthIncomeMinor: 0,
    monthExpenseMinor: 0,
    outstandingLoanCount: 0,
    outstandingBorrowedCount: 0,
  );
}

@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get totalAmountMinor => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Set when the user **explicitly** marks the project complete; null means
  /// ongoing. Deliberately not derived from payments — a project can be
  /// delivered while money is still owed, and fully paid while work continues.
  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProjectPaymentRow')
class ProjectPayments extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get projectId => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Instalments against a loan — money coming back on something you lent, or
/// money you paid back on something you borrowed.
///
/// Deliberately **not** mirrored into [Records], which is where this differs
/// from [ProjectPayments]. A project payment is new income entering your
/// finances, so it needs a record. A loan repayment is your own money
/// returning: minting an income record for it would inflate your lifetime
/// income and double-count against the balance, since the loan principal is
/// already carried in `outstanding*`. Instalments move the outstanding number
/// instead — see `watchStats`.
class LoanPayments extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();

  /// The `records.id` of the loan row this repays.
  TextColumn get loanId => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
    tables: [Records, Categories, Projects, ProjectPayments, LoanPayments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 dev data: drop old tables and create new schema.
            await customStatement('DROP TABLE IF EXISTS transactions');
            await customStatement('DROP TABLE IF EXISTS categories');
            await m.createTable(records);
          }
          if (from < 3) {
            await m.addColumn(records, records.categoryId);
            await m.createTable(categories);
          }
          if (from < 4) {
            await m.createTable(projects);
            await m.createTable(projectPayments);
          }
          if (from < 5) {
            await m.addColumn(records, records.projectPaymentId);
            // Backfill: every existing project payment becomes an income
            // record so older projects also count toward the balance.
            final pays = await select(projectPayments).get();
            for (final pay in pays) {
              final proj = await (select(projects)
                    ..where((p) => p.id.equals(pay.projectId)))
                  .getSingleOrNull();
              await into(records).insert(
                _projectIncomeCompanion(
                  projectName: proj?.name ?? 'Project',
                  projectCategoryId: proj?.categoryId,
                  amountMinor: pay.amountMinor,
                  note: pay.note,
                  paidAt: pay.paidAt,
                  paymentId: pay.id,
                ),
              );
            }
          }
          if (from < 6) {
            // Explicit project completion. No backfill: completion is a user
            // decision, so every pre-existing project starts as "Ongoing"
            // even if it is already fully paid.
            await m.addColumn(projects, projects.completedAt);
          }
          if (from < 7) {
            // Loan instalments. No backfill and no data rewrite: a loan that
            // was already marked returned stays returned, and one that wasn't
            // simply starts with no instalments, which reads as "nothing
            // repaid yet" — exactly what it meant before this table existed.
            await m.createTable(loanPayments);
          }
        },
      );

  // --- Backup helpers ---
  /// Run a checkpointed snapshot of the DB into [destPath] via VACUUM INTO.
  /// Produces a consistent, app-stable copy without closing connections.
  Future<void> snapshotTo(String destPath) async {
    await customStatement("VACUUM INTO ?", [destPath]);
  }

  Future<int> countRecords() async {
    final row = await customSelect('SELECT COUNT(*) AS c FROM records')
        .getSingle();
    return row.read<int>('c');
  }

  Future<bool> isEmpty() async => (await countRecords()) == 0;

  /// Emits once whenever any table changes (insert/update/delete). Powers the
  /// debounced auto-backup so edits are saved to Drive without a button press.
  Stream<void> watchAnyChange() => tableUpdates();

  /// Case-insensitive "this column contains this text", with **no pattern
  /// language at all**.
  ///
  /// Deliberately `instr()` rather than `LIKE '%…%'`: LIKE would treat `%` and
  /// `_` in *user input* as wildcards — the seed data contains "Advance — 30%",
  /// so searching `30%` would match every row — and drift 2.21's `like()`
  /// exposes no ESCAPE clause. `instr` has no wildcards, so there is nothing to
  /// escape and no injection surface.
  ///
  /// A NULL column yields NULL, which is false in a WHERE — exactly right for
  /// the nullable description/counterparty columns.
  static Expression<bool> _containsCI(
          Expression<String> column, String needle) =>
      FunctionCallExpression<int>('instr', [
        column.lower(),
        Variable.withString(needle.toLowerCase()),
      ]).isBiggerThanValue(0);

  Stream<List<RecordRow>> watchRecords({
    RecordType? type,
    Set<RecordType>? typesIn,
    bool? loanReturned,
    DateTime? from,
    DateTime? to,
    int? limit,
    /// Category *filter* — an OR across the chosen categories, ANDed with
    /// everything else. Distinct from [categoryIdsIn], which is part of the
    /// free-text search's OR group; empty means "no category filter".
    List<String>? categoryIds,
    String? query,
    List<String>? categoryIdsIn,
  }) {
    final q = select(records);
    if (type != null) q.where((r) => r.type.equalsValue(type));
    if (typesIn != null && typesIn.isNotEmpty) {
      q.where((r) => r.type.isInValues(typesIn.toList()));
    }
    if (loanReturned != null) {
      q.where((r) => r.returned.equals(loanReturned));
    }
    if (from != null) {
      q.where((r) => r.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where((r) => r.occurredAt.isSmallerOrEqualValue(to));
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      q.where((r) => r.categoryId.isIn(categoryIds));
    }
    // Free-text search: ORed across the searchable text columns, then ANDed
    // with every filter above. `type` is a TEXT enum column and is deliberately
    // never searched. Category *names* live in another table and cannot be
    // joined here, so callers resolve matching ids and pass [categoryIdsIn].
    if (query != null && query.isNotEmpty) {
      q.where((r) => Expression.or([
            _containsCI(r.description, query),
            _containsCI(r.counterparty, query),
            if (categoryIdsIn != null && categoryIdsIn.isNotEmpty)
              r.categoryId.isIn(categoryIdsIn),
          ]));
    }
    q.orderBy([
      (r) => OrderingTerm.desc(r.occurredAt),
      (r) => OrderingTerm.desc(r.createdAt),
    ]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Future<int?> earliestRecordYear() async {
    final q = selectOnly(records)
      ..addColumns([records.occurredAt.min()])
      ..limit(1);
    final row = await q.getSingleOrNull();
    final v = row?.read(records.occurredAt.min());
    return v?.year;
  }

  Future<void> upsertRecord(RecordsCompanion data) =>
      into(records).insertOnConflictUpdate(data);

  Future<int> deleteRecord(String id) async {
    return transaction(() async {
      final row =
          await (select(records)..where((r) => r.id.equals(id))).getSingleOrNull();
      // If this record is the money side of a project payment, drop the
      // payment too so the project's "Paid" total stays consistent.
      final paymentId = row?.projectPaymentId;
      if (paymentId != null) {
        await (delete(projectPayments)..where((p) => p.id.equals(paymentId)))
            .go();
      }
      return (delete(records)..where((r) => r.id.equals(id))).go();
    });
  }

  /// Keep a project payment in sync when its linked income record is edited
  /// from the Records screen.
  Future<void> syncProjectPaymentFromRecord(
    String paymentId, {
    required int amountMinor,
    required DateTime paidAt,
  }) =>
      (update(projectPayments)..where((p) => p.id.equals(paymentId))).write(
        ProjectPaymentsCompanion(
          amountMinor: Value(amountMinor),
          paidAt: Value(paidAt),
        ),
      );

  Future<void> markLoanReturned(String id, {required bool returned}) async {
    await (update(records)..where((r) => r.id.equals(id))).write(
      RecordsCompanion(
        returned: Value(returned),
        returnedAt: Value(returned ? DateTime.now() : null),
      ),
    );
  }

  // ── Loan instalments ────────────────────────────────────────────────────────

  Stream<RecordRow?> watchLoan(String id) =>
      (select(records)..where((r) => r.id.equals(id))).watchSingleOrNull();

  Stream<List<LoanPayment>> watchLoanPayments(String loanId) =>
      (select(loanPayments)
            ..where((p) => p.loanId.equals(loanId))
            ..orderBy([(p) => OrderingTerm.asc(p.paidAt)]))
          .watch();

  /// Total repaid per loan id, for every loan at once.
  ///
  /// One grouped query rather than one per row: the loans list renders every
  /// outstanding loan, and a per-row query would be N subscriptions that all
  /// re-fire on any write.
  Stream<Map<String, int>> watchRepaidTotals() {
    final loanId = loanPayments.loanId;
    final total = loanPayments.amountMinor.sum();
    final q = selectOnly(loanPayments)
      ..addColumns([loanId, total])
      ..groupBy([loanId]);
    return q.watch().map((rows) => {
          for (final row in rows) row.read(loanId)!: row.read(total) ?? 0,
        });
  }

  /// Adds an instalment and, when the loan is now fully covered, marks it
  /// settled in the same transaction.
  ///
  /// Auto-settling is a convenience, not a derivation: [markLoanReturned] can
  /// still settle a loan early (you forgave the rest) or re-open one, and this
  /// never contradicts that — it only fires on the transition into fully-paid.
  Future<void> addLoanPayment({
    required String loanId,
    required int amountMinor,
    String? note,
    required DateTime paidAt,
  }) async {
    await transaction(() async {
      await into(loanPayments).insert(
        LoanPaymentsCompanion.insert(
          loanId: loanId,
          amountMinor: amountMinor,
          note: Value(note),
          paidAt: paidAt,
        ),
      );
      await _settleIfCovered(loanId);
    });
  }

  Future<void> deleteLoanPayment(String paymentId) async {
    await transaction(() async {
      final pay = await (select(loanPayments)
            ..where((p) => p.id.equals(paymentId)))
          .getSingleOrNull();
      if (pay == null) return;
      await (delete(loanPayments)..where((p) => p.id.equals(paymentId))).go();
      // Removing an instalment can drop a settled loan back below its
      // principal, so the settled mark has to be re-evaluated both ways.
      await _settleIfCovered(pay.loanId);
    });
  }

  /// Sum of instalments against one loan.
  Future<int> repaidTotal(String loanId) async {
    final total = loanPayments.amountMinor.sum();
    final row = await (selectOnly(loanPayments)
          ..addColumns([total])
          ..where(loanPayments.loanId.equals(loanId)))
        .getSingle();
    return row.read(total) ?? 0;
  }

  Future<void> _settleIfCovered(String loanId) async {
    final loan = await (select(records)..where((r) => r.id.equals(loanId)))
        .getSingleOrNull();
    if (loan == null) return;
    final repaid = await repaidTotal(loanId);
    final covered = repaid >= loan.amountMinor;
    if (covered == loan.returned) return;
    await (update(records)..where((r) => r.id.equals(loanId))).write(
      RecordsCompanion(
        returned: Value(covered),
        returnedAt: Value(covered ? DateTime.now() : null),
      ),
    );
  }

  Stream<List<CategoryRow>> watchCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();

  Future<CategoryRow> addCategory(String name) async {
    final id = _uuid.v4();
    await into(categories).insert(
      CategoriesCompanion.insert(id: Value(id), name: name),
    );
    return (select(categories)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<void> renameCategory(String id, String name) =>
      (update(categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(name: Value(name)));

  Future<void> deleteCategory(String id) async {
    // Null out references so existing records/projects don't become orphaned.
    await (update(records)..where((r) => r.categoryId.equals(id)))
        .write(const RecordsCompanion(categoryId: Value(null)));
    await (update(projects)..where((p) => p.categoryId.equals(id)))
        .write(const ProjectsCompanion(categoryId: Value(null)));
    await (delete(categories)..where((c) => c.id.equals(id))).go();
  }

  Stream<DashboardStats> watchStats() {
    // Two streams because outstanding is now `principal - repaid`: the numbers
    // have to recompute when either side moves, and a record-only watch would
    // leave the dashboard stale after an instalment.
    return Rx.combineLatest2<List<RecordRow>, Map<String, int>, DashboardStats>(
        select(records).watch(), watchRepaidTotals(), (rows, repaidBy) {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);

      int income = 0, expense = 0, outLoan = 0, outCount = 0;
      int outBorrowed = 0, outBorrowedCount = 0;
      int monthInc = 0, monthExp = 0;
      for (final r in rows) {
        switch (r.type) {
          case RecordType.income:
            income += r.amountMinor;
            if (!r.occurredAt.isBefore(monthStart) &&
                r.occurredAt.isBefore(nextMonth)) {
              monthInc += r.amountMinor;
            }
            break;
          case RecordType.expense:
            expense += r.amountMinor;
            if (!r.occurredAt.isBefore(monthStart) &&
                r.occurredAt.isBefore(nextMonth)) {
              monthExp += r.amountMinor;
            }
            break;
          // Outstanding is what is *still* owed. Clamped at zero so an
          // overpayment can't turn into negative debt and quietly inflate the
          // balance; the surplus is the loan's business, not the dashboard's.
          case RecordType.loanGiven:
            if (!r.returned) {
              final left = r.amountMinor - (repaidBy[r.id] ?? 0);
              if (left > 0) {
                outLoan += left;
                outCount += 1;
              }
            }
            break;
          case RecordType.loanTaken:
            if (!r.returned) {
              final left = r.amountMinor - (repaidBy[r.id] ?? 0);
              if (left > 0) {
                outBorrowed += left;
                outBorrowedCount += 1;
              }
            }
            break;
        }
      }
      return DashboardStats(
        incomeMinor: income,
        expenseMinor: expense,
        outstandingLoanMinor: outLoan,
        outstandingBorrowedMinor: outBorrowed,
        monthIncomeMinor: monthInc,
        monthExpenseMinor: monthExp,
        outstandingLoanCount: outCount,
        outstandingBorrowedCount: outBorrowedCount,
      );
    });
  }

  // ── Projects ────────────────────────────────────────────────────────────────

  Stream<List<ProjectRow>> watchProjects() =>
      (select(projects)
            ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .watch();

  /// A single project as a live stream — lets the detail page stay in sync with
  /// edits and completion changes instead of holding a stale row snapshot.
  Stream<ProjectRow?> watchProject(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<void> upsertProject(ProjectsCompanion data) =>
      into(projects).insertOnConflictUpdate(data);

  /// Explicitly mark a project complete (or re-open it). Payments are left
  /// completely alone — completion is a workflow flag, not a money operation.
  Future<void> setProjectCompleted(String id, {required bool completed}) =>
      (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(
          completedAt: Value(completed ? DateTime.now() : null),
        ),
      );

  Future<void> deleteProject(String id) async {
    await transaction(() async {
      final paymentIds = await (selectOnly(projectPayments)
            ..addColumns([projectPayments.id])
            ..where(projectPayments.projectId.equals(id)))
          .map((r) => r.read(projectPayments.id)!)
          .get();
      if (paymentIds.isNotEmpty) {
        await (delete(records)
              ..where((r) => r.projectPaymentId.isIn(paymentIds)))
            .go();
      }
      await (delete(projectPayments)..where((p) => p.projectId.equals(id)))
          .go();
      await (delete(projects)..where((p) => p.id.equals(id))).go();
    });
  }

  // ── Project Payments ─────────────────────────────────────────────────────────

  Stream<List<ProjectPaymentRow>> watchProjectPayments(String projectId) =>
      (select(projectPayments)
            ..where((p) => p.projectId.equals(projectId))
            ..orderBy([(p) => OrderingTerm.asc(p.paidAt)]))
          .watch();

  /// Sum of payments received per project (projectId → total minor units).
  /// Powers the Projects summary board without opening one stream per card.
  Stream<Map<String, int>> watchReceivedByProject() {
    final sum = projectPayments.amountMinor.sum();
    final query = selectOnly(projectPayments)
      ..addColumns([projectPayments.projectId, sum])
      ..groupBy([projectPayments.projectId]);
    return query.watch().map((rows) {
      final map = <String, int>{};
      for (final r in rows) {
        final id = r.read(projectPayments.projectId);
        if (id != null) map[id] = r.read(sum) ?? 0;
      }
      return map;
    });
  }

  /// Records a project payment AND its matching income record (the money the
  /// project earned), atomically. The income record flows into the balance,
  /// charts, totals and recent activity automatically.
  Future<void> addProjectPayment({
    required String projectId,
    required String projectName,
    String? projectCategoryId,
    required int amountMinor,
    String? note,
    required DateTime paidAt,
  }) async {
    final paymentId = _uuid.v4();
    await transaction(() async {
      await into(projectPayments).insert(
        ProjectPaymentsCompanion.insert(
          id: Value(paymentId),
          projectId: projectId,
          amountMinor: amountMinor,
          note: Value(note),
          paidAt: paidAt,
        ),
      );
      await into(records).insert(
        _projectIncomeCompanion(
          projectName: projectName,
          projectCategoryId: projectCategoryId,
          amountMinor: amountMinor,
          note: note,
          paidAt: paidAt,
          paymentId: paymentId,
        ),
      );
    });
  }

  Future<void> deleteProjectPayment(String id) async {
    await transaction(() async {
      await (delete(records)..where((r) => r.projectPaymentId.equals(id))).go();
      await (delete(projectPayments)..where((p) => p.id.equals(id))).go();
    });
  }

  /// Builds the income [RecordsCompanion] that mirrors a project payment.
  static RecordsCompanion _projectIncomeCompanion({
    required String projectName,
    required String? projectCategoryId,
    required int amountMinor,
    required String? note,
    required DateTime paidAt,
    required String paymentId,
  }) {
    final trimmedNote = note?.trim();
    final desc = (trimmedNote != null && trimmedNote.isNotEmpty)
        ? 'Project: $projectName — $trimmedNote'
        : 'Project: $projectName';
    return RecordsCompanion.insert(
      amountMinor: amountMinor,
      type: RecordType.income,
      description: Value(desc),
      occurredAt: paidAt,
      categoryId: Value(projectCategoryId),
      projectPaymentId: Value(paymentId),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'xpense.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
