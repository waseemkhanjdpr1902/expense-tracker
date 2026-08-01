import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';

/// Per-section search providers.
///
/// Deliberately separate rather than one aggregate result object: each section
/// then renders the moment *it* resolves, which is what makes the staggered
/// entrance look organic. An aggregate would gate every section on the slowest.
///
/// All of them are `autoDispose` — a family keyed by free text has an unbounded
/// key space, so without it every query the user ever types would retain a live
/// stream and its last result for the life of the process.

/// Key for a searched slice of records.
///
/// Hand-written `==`/`hashCode` matching the house pattern in `providers.dart`.
class RecordSearchQuery {
  /// Normalised (see `normalizeQuery`) and non-empty.
  final String query;
  final Set<RecordType> types;
  final bool? loanReturned;
  final int? limit;

  const RecordSearchQuery({
    required this.query,
    required this.types,
    this.loanReturned,
    this.limit,
  });

  @override
  bool operator ==(Object other) =>
      other is RecordSearchQuery &&
      other.query == query &&
      other.loanReturned == loanReturned &&
      other.limit == limit &&
      other.types.length == types.length &&
      other.types.containsAll(types);

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAllUnordered(types),
        loanReturned,
        limit,
      );
}

final recordSearchProvider = StreamProvider.autoDispose
    .family<List<RecordRow>, RecordSearchQuery>((ref, q) {
  return ref.watch(databaseProvider).watchRecords(
        typesIn: q.types,
        loanReturned: q.loanReturned,
        query: q.query,
        categoryIdsIn: matchingCategoryIds(ref, q.query),
        limit: q.limit,
      );
});

/// Projects match on name + description, filtered in Dart: the table is tiny,
/// already fully streamed, and the Projects page filters client-side too.
final projectSearchProvider =
    Provider.autoDispose.family<List<ProjectRow>, String>((ref, query) {
  final needle = query.toLowerCase();
  final all = ref.watch(projectsProvider).valueOrNull ?? const <ProjectRow>[];
  return [
    for (final p in all)
      if ('${p.name} ${p.description ?? ''}'.toLowerCase().contains(needle)) p,
  ];
});

final categorySearchProvider =
    Provider.autoDispose.family<List<CategoryRow>, String>((ref, query) {
  final needle = query.toLowerCase();
  final all = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryRow>[];
  return [
    for (final c in all)
      if (c.name.toLowerCase().contains(needle)) c,
  ];
});

/// A one-shot hand-off from global search to a shell tab, so "See all" lands on
/// a page that is already showing the same query rather than an unfiltered list.
/// The destination consumes it (and nulls it) in a `ref.listen`.
class PendingSearch {
  /// Shell tab index: 1 Records, 2 Loans, 3 Projects.
  final int tab;
  final String query;
  final RecordsFilter? recordsType;
  final String? categoryId;

  const PendingSearch({
    required this.tab,
    required this.query,
    this.recordsType,
    this.categoryId,
  });
}

final pendingSearchProvider = StateProvider<PendingSearch?>((_) => null);

/// Set by a page while its scoped search field is open, so the shell's back
/// handler collapses the field before touching tab history. Pages must clear it
/// on close *and* in dispose.
final searchBackInterceptorProvider =
    StateProvider<VoidCallback?>((_) => null);
