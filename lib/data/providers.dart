import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/chart_data.dart';
import '../core/date_range.dart';
import 'database.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) =>
    Connectivity().onConnectivityChanged);

/// App version name (from the native build / pubspec), e.g. "1.0.2".
/// Read at runtime so it never goes stale on a version bump.
final appVersionProvider = FutureProvider<String>((_) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Fires whenever any table changes — used to debounce automatic backups.
final dataChangeProvider = StreamProvider<void>(
    (ref) => ref.watch(databaseProvider).watchAnyChange());

final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) {
  return ref.watch(databaseProvider).watchStats();
});

final recentRecordsProvider = StreamProvider<List<RecordRow>>((ref) {
  return ref.watch(databaseProvider).watchRecords(limit: 8);
});

class RecordsFilter {
  final Set<RecordType> types;
  const RecordsFilter(this.types);

  static const all =
      RecordsFilter({RecordType.income, RecordType.expense});
  static const incomeOnly = RecordsFilter({RecordType.income});
  static const expenseOnly = RecordsFilter({RecordType.expense});

  @override
  bool operator ==(Object other) =>
      other is RecordsFilter &&
      other.types.length == types.length &&
      other.types.containsAll(types);

  @override
  int get hashCode => Object.hashAll(types);
}

class RecordsQuery {
  final RecordsFilter type;
  final DateRangeFilter range;
  final String? categoryId;
  final int limit;

  /// Normalised free-text search, or null. MUST appear in == and hashCode:
  /// equal keys serve the cached stream, so omitting it makes typing silently
  /// do nothing.
  final String? query;

  const RecordsQuery({
    required this.type,
    required this.range,
    this.categoryId,
    this.limit = 50,
    this.query,
  });

  @override
  bool operator ==(Object other) =>
      other is RecordsQuery &&
      other.type == type &&
      other.range == range &&
      other.categoryId == categoryId &&
      other.limit == limit &&
      other.query == query;

  @override
  int get hashCode => Object.hash(type, range, categoryId, limit, query);
}

// autoDispose: the `query` field makes this family's key space unbounded, so
// without it every search term ever typed would retain a live stream.
final filteredRecordsProvider = StreamProvider.autoDispose
    .family<List<RecordRow>, RecordsQuery>((ref, q) {
  final r = q.range.resolveOrNull(DateTime.now());
  return ref.watch(databaseProvider).watchRecords(
        typesIn: q.type.types,
        from: r?.start,
        to: r?.end,
        categoryId: q.categoryId,
        query: q.query,
        categoryIdsIn: matchingCategoryIds(ref, q.query),
        limit: q.limit,
      );
});

/// Loan direction filter for the Loans screen.
enum LoanTypeFilter { all, lent, borrowed }

extension LoanTypeFilterX on LoanTypeFilter {
  Set<RecordType> get types => switch (this) {
        LoanTypeFilter.all =>
          const {RecordType.loanGiven, RecordType.loanTaken},
        LoanTypeFilter.lent => const {RecordType.loanGiven},
        LoanTypeFilter.borrowed => const {RecordType.loanTaken},
      };
}

/// Query for the Loans list — a tab (returned vs outstanding) plus the shared
/// type / category / date-range filters.
class LoansQuery {
  final bool returned;
  final LoanTypeFilter type;
  final String? categoryId;
  final DateRangeFilter range;
  /// Normalised free-text search, or null. Must stay in == / hashCode.
  final String? query;

  const LoansQuery({
    required this.returned,
    required this.type,
    required this.range,
    this.categoryId,
    this.query,
  });

  @override
  bool operator ==(Object other) =>
      other is LoansQuery &&
      other.returned == returned &&
      other.type == type &&
      other.categoryId == categoryId &&
      other.range == range &&
      other.query == query;

  @override
  int get hashCode =>
      Object.hash(returned, type, categoryId, range, query);
}

final loansProvider = StreamProvider.autoDispose
    .family<List<RecordRow>, LoansQuery>((ref, q) {
  final r = q.range.resolveOrNull(DateTime.now());
  return ref.watch(databaseProvider).watchRecords(
        typesIn: q.type.types,
        loanReturned: q.returned,
        categoryId: q.categoryId,
        from: r?.start,
        to: r?.end,
        query: q.query,
        categoryIdsIn: matchingCategoryIds(ref, q.query),
      );
});

final earliestRecordYearProvider = FutureProvider<int>((ref) async {
  final y = await ref.watch(databaseProvider).earliestRecordYear();
  return y ?? DateTime.now().year;
});

final categoriesProvider = StreamProvider<List<CategoryRow>>((ref) =>
    ref.watch(databaseProvider).watchCategories());

/// Ids of categories whose *name* contains [query], resolved in Dart because
/// records store only a category id and the codebase has no SQL joins. Folded
/// into the record WHERE so searching "groceries" finds rows categorised
/// Groceries even when no description mentions the word.
List<String> matchingCategoryIds(Ref ref, String? query) {
  if (query == null || query.isEmpty) return const [];
  final needle = query.toLowerCase();
  final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return [
    for (final c in cats)
      if (c.name.toLowerCase().contains(needle)) c.id,
  ];
}

/// Status filter for the Projects screen. Completion is an **explicit** user
/// mark (`Projects.completedAt`), never derived from payments.
enum ProjectStatusFilter { all, ongoing, completed }

final projectsProvider = StreamProvider<List<ProjectRow>>(
    (ref) => ref.watch(databaseProvider).watchProjects());

/// A single project, live. The detail page watches this so a completion toggle
/// or an edit refreshes in place instead of showing a stale snapshot.
final projectByIdProvider = StreamProvider.family<ProjectRow?, String>(
    (ref, id) => ref.watch(databaseProvider).watchProject(id));

final projectPaymentsProvider =
    StreamProvider.family<List<ProjectPaymentRow>, String>(
  (ref, projectId) =>
      ref.watch(databaseProvider).watchProjectPayments(projectId),
);

// ── Loan instalments ─────────────────────────────────────────────────────────

/// A single loan, live — the detail page's source of truth, so an instalment
/// or a settle toggle refreshes in place.
final loanByIdProvider = StreamProvider.family<RecordRow?, String>(
    (ref, id) => ref.watch(databaseProvider).watchLoan(id));

final loanPaymentsProvider = StreamProvider.family<List<LoanPayment>, String>(
  (ref, loanId) => ref.watch(databaseProvider).watchLoanPayments(loanId),
);

/// Repaid-to-date for every loan, keyed by loan id.
///
/// One grouped query shared by the whole list rather than a family keyed by
/// loan id: the loans page renders every outstanding loan, so a family would
/// mean N subscriptions all re-firing on any write.
final loanRepaidTotalsProvider = StreamProvider<Map<String, int>>(
    (ref) => ref.watch(databaseProvider).watchRepaidTotals());

/// projectId → total payments received (minor units). Feeds the Projects board.
final receivedByProjectProvider = StreamProvider<Map<String, int>>(
    (ref) => ref.watch(databaseProvider).watchReceivedByProject());

final chartDataProvider =
    StreamProvider.family<List<ChartPoint>, ChartPeriod>((ref, period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final from = switch (period) {
    ChartPeriod.week => today.subtract(const Duration(days: 6)),
    ChartPeriod.month => today.subtract(const Duration(days: 29)),
    ChartPeriod.year => DateTime(now.year, 1, 1),
  };
  return ref
      .watch(databaseProvider)
      .watchRecords(
        typesIn: {RecordType.income, RecordType.expense},
        from: from,
        to: now,
      )
      .map((rows) => _aggregateChartPoints(rows, period, from, now));
});

// ── Per-filter totals (income + expense sum, no row limit) ────────────────────

class RecordsTotals {
  final int incomeMinor;
  final int expenseMinor;
  const RecordsTotals({required this.incomeMinor, required this.expenseMinor});
  int get netMinor => incomeMinor - expenseMinor;
  static const zero = RecordsTotals(incomeMinor: 0, expenseMinor: 0);
}

/// Like RecordsQuery but without `limit` — used for accurate totals.
class RecordsTotalsQuery {
  final RecordsFilter type;
  final DateRangeFilter range;
  final String? categoryId;
  /// Normalised free-text search, or null. Must stay in == / hashCode.
  final String? query;

  const RecordsTotalsQuery(
      {required this.type,
      required this.range,
      this.categoryId,
      this.query});

  @override
  bool operator ==(Object other) =>
      other is RecordsTotalsQuery &&
      other.type == type &&
      other.range == range &&
      other.categoryId == categoryId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(type, range, categoryId, query);
}

final filteredTotalsProvider = StreamProvider.autoDispose
    .family<RecordsTotals, RecordsTotalsQuery>((ref, q) {
  final r = q.range.resolveOrNull(DateTime.now());
  return ref
      .watch(databaseProvider)
      .watchRecords(
        typesIn: q.type.types,
        from: r?.start,
        to: r?.end,
        categoryId: q.categoryId,
        query: q.query,
        categoryIdsIn: matchingCategoryIds(ref, q.query),
        // no limit — we need totals across all matching records
      )
      .map((rows) {
    int income = 0, expense = 0;
    for (final row in rows) {
      if (row.type == RecordType.income) income += row.amountMinor;
      if (row.type == RecordType.expense) expense += row.amountMinor;
    }
    return RecordsTotals(incomeMinor: income, expenseMinor: expense);
  });
});

// ── Custom-range chart data ────────────────────────────────────────────────────

class ChartDateRange {
  final DateTime from;
  final DateTime to;
  const ChartDateRange({required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      other is ChartDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final customChartDataProvider =
    StreamProvider.family<List<ChartPoint>, ChartDateRange>((ref, range) {
  return ref
      .watch(databaseProvider)
      .watchRecords(
        typesIn: {RecordType.income, RecordType.expense},
        from: range.from,
        to: range.to,
      )
      .map((rows) => _aggregateCustomChartPoints(rows, range.from, range.to));
});

List<ChartPoint> _aggregateCustomChartPoints(
    List<RecordRow> rows, DateTime from, DateTime to) {
  final days = to.difference(from).inDays;
  final useMonthly = days > 90;
  final Map<DateTime, (double inc, double exp)> buckets = {};

  if (useMonthly) {
    var cursor = DateTime(from.year, from.month, 1);
    final lastMonth = DateTime(to.year, to.month, 1);
    while (!cursor.isAfter(lastMonth)) {
      buckets[cursor] = (0, 0);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
  } else {
    for (var i = 0; i <= days; i++) {
      final d = from.add(Duration(days: i));
      buckets[DateTime(d.year, d.month, d.day)] = (0, 0);
    }
  }

  for (final r in rows) {
    final DateTime key = useMonthly
        ? DateTime(r.occurredAt.year, r.occurredAt.month, 1)
        : DateTime(
            r.occurredAt.year, r.occurredAt.month, r.occurredAt.day);
    if (!buckets.containsKey(key)) continue;
    final (inc, exp) = buckets[key]!;
    buckets[key] = r.type == RecordType.income
        ? (inc + r.amountMinor.toDouble(), exp)
        : (inc, exp + r.amountMinor.toDouble());
  }

  final sorted = buckets.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return sorted
      .map((e) => ChartPoint(
          date: e.key, income: e.value.$1, expense: e.value.$2))
      .toList();
}

List<ChartPoint> _aggregateChartPoints(
  List<RecordRow> rows,
  ChartPeriod period,
  DateTime from,
  DateTime now,
) {
  // Build bucket map
  final Map<DateTime, (double inc, double exp)> buckets = {};

  if (period == ChartPeriod.year) {
    // One bucket per month Jan–current month
    for (var m = 1; m <= now.month; m++) {
      buckets[DateTime(now.year, m, 1)] = (0, 0);
    }
  } else {
    final days = period == ChartPeriod.week ? 7 : 30;
    for (var i = 0; i < days; i++) {
      final d = from.add(Duration(days: i));
      buckets[DateTime(d.year, d.month, d.day)] = (0, 0);
    }
  }

  for (final r in rows) {
    final DateTime key;
    if (period == ChartPeriod.year) {
      key = DateTime(r.occurredAt.year, r.occurredAt.month, 1);
    } else {
      key = DateTime(
          r.occurredAt.year, r.occurredAt.month, r.occurredAt.day);
    }
    if (!buckets.containsKey(key)) continue;
    final (inc, exp) = buckets[key]!;
    if (r.type == RecordType.income) {
      buckets[key] = (inc + r.amountMinor.toDouble(), exp);
    } else {
      buckets[key] = (inc, exp + r.amountMinor.toDouble());
    }
  }

  final sorted = buckets.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return sorted
      .map((e) => ChartPoint(
            date: e.key,
            income: e.value.$1,
            expense: e.value.$2,
          ))
      .toList();
}
