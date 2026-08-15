import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hero.dart';
import '../../../core/currency.dart';
import '../../../core/date_range.dart';
import '../../../core/formatters.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/haptics.dart';
import '../../../core/routes.dart';
import 'loan_detail_page.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../data/settings_repo.dart';
import '../../records/ui/add_record_sheet.dart';
import '../../../core/debounce.dart';
import '../../../core/search_text.dart';
import '../../search/data/search_providers.dart';
import '../../search/ui/searchable_app_bar.dart';
import '../../shared/app_sheet.dart';
import '../../shared/loading.dart';
import '../../shared/empty_state.dart';
import '../../../core/icons.dart';
import '../../shared/totals_strip.dart';

class LoansPage extends ConsumerStatefulWidget {
  const LoansPage({super.key});

  @override
  ConsumerState<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends ConsumerState<LoansPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final TabController _tab;

  // ── Scoped search ──────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _searchDebounce = Debouncer();
  late final AnimationController _searchAnim = AnimationController(
    vsync: this,
    duration: AppMotion.expand,
    reverseDuration: AppMotion.slow,
  );
  String? _query;

  LoanTypeFilter _type = LoanTypeFilter.all;
  /// Multi-select: empty means no category filter.
  Set<String> _categoryIds = {};
  DateRangeFilter _range = DateRangeFilter.all;

  bool get _hasActiveFilters =>
      _type != LoanTypeFilter.all ||
      _categoryIds.isNotEmpty ||
      _range != DateRangeFilter.all;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce.dispose();
    _searchAnim.dispose();
    ref.read(searchBackInterceptorProvider.notifier).state = null;
    super.dispose();
  }

  // ── Scoped search plumbing ─────────────────────────────────────────────────

  void _openSearch() {
    _searchAnim.forward();
    ref.read(searchBackInterceptorProvider.notifier).state = _closeSearch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchAnim.reverse();
    ref.read(searchBackInterceptorProvider.notifier).state = null;
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce.cancel();
    setState(() => _query = null);
    _closeSearch();
  }

  void _setQuery(String raw) {
    final next = normalizeQuery(raw);
    if (next == _query) return;
    setState(() => _query = next);
  }

  void _openFilterSheet() {
    AppSheet.show(
      context,
      transparent: true,
      builder: (_) => _LoansFilterSheet(
        initialType: _type,
        initialCategoryIds: _categoryIds,
        initialRange: _range,
        onChanged: (type, categoryIds, range) {
          setState(() {
            _type = type;
            _categoryIds = categoryIds;
            _range = range;
          });
        },
        onReset: () {
          setState(() {
            _type = LoanTypeFilter.all;
            _categoryIds = {};
            _range = DateRangeFilter.all;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Deep-link from global search. Uses `watch`, not `listen`: the shell's
    // PageView builds pages lazily, so a page that had never been built yet
    // would miss the change entirely — `listen` only fires on transitions
    // observed while already listening. Applying post-frame (setState is
    // illegal during build) and clearing the provider makes this run once.
    final pending = ref.watch(pendingSearchProvider);
    if (pending != null && pending.tab == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _query = pending.query;
          _searchController.text = pending.query;
          if (pending.categoryId != null) _categoryIds = {pending.categoryId!};
        });
        _searchAnim.value = 1;
        ref.read(searchBackInterceptorProvider.notifier).state = _closeSearch;
        ref.read(pendingSearchProvider.notifier).state = null;
      });
    }

    // Both tabs carry the query: a name typed while on Outstanding should
    // still find the settled loan under Returned.
    final outstandingQuery = LoansQuery(
      returned: false,
      type: _type,
      categoryIds: categoryKey(_categoryIds),
      range: _range,
      query: _query,
    );
    final returnedQuery = LoansQuery(
      returned: true,
      type: _type,
      categoryIds: categoryKey(_categoryIds),
      range: _range,
      query: _query,
    );
    final outstanding = ref.watch(loansProvider(outstandingQuery));
    final returned = ref.watch(loansProvider(returnedQuery));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SearchableAppBar(
        title: 'Loans',
        animation: _searchAnim,
        controller: _searchController,
        focusNode: _searchFocus,
        query: _query,
        onQueryChanged: (raw) =>
            _searchDebounce(() => mounted ? _setQuery(raw) : null),
        onSubmitted: (raw) => _searchDebounce.flush(() => _setQuery(raw)),
        onOpen: _openSearch,
        onClose: _closeSearch,
        onClear: _clearSearch,
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded),
                if (_hasActiveFilters)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.palette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => openAddRecordSheet(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            indicatorColor: context.palette.accent,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: context.ink,
            unselectedLabelColor: context.inkSubtle,
            labelStyle:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppTextStyles.body,
            tabs: const [
              Tab(text: 'Outstanding'),
              Tab(text: 'Returned'),
            ],
          ),
        ),
      ),
      body: HeroScope(
        name: 'loans',
        child: TabBarView(
        controller: _tab,
        children: [
          _LoansList(
              loans: outstanding, isOutstanding: true, query: outstandingQuery),
          _LoansList(
              loans: returned, isOutstanding: false, query: returnedQuery),
        ],
        ),
      ),
    );
  }
}

class _LoansList extends ConsumerWidget {
  const _LoansList(
      {required this.loans,
      required this.isOutstanding,
      required this.query});
  final AsyncValue<List<RecordRow>> loans;
  final bool isOutstanding;
  final LoansQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    return RefreshIndicator(
      color: context.palette.accent,
      onRefresh: () async {
        ref.invalidate(loansProvider);
        await ref.read(loansProvider(query).future);
      },
      child: XSwitcher(
      child: loans.when(
        loading: () => const DelayedVisible(
                key: ValueKey('loans-loading'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SkeletonRows(rows: 4),
                )),
        error: (e, _) => Center(
            key: const ValueKey('loans-error'), child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              key: const ValueKey('loans-empty'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: EmptyState(
                    illustration: query.query == null
                        ? 'assets/illustrations/loans.svg'
                        : null,
                    icon: query.query != null ? AppIcons.noResults : null,
                    title: query.query != null
                        ? 'No matches for "${query.query}"'
                        : isOutstanding
                            ? 'No outstanding loans'
                            : 'Nothing returned yet',
                    message: query.query != null
                        ? 'Try a different name or note.'
                        : isOutstanding
                            ? 'When you lend or borrow money, it shows up here.'
                            : 'Loans marked as returned will appear here.',
                  ),
                ),
              ],
            );
          }
          final lent = items
              .where((r) => r.type == RecordType.loanGiven)
              .fold<int>(0, (s, r) => s + r.amountMinor);
          final borrowed = items
              .where((r) => r.type == RecordType.loanTaken)
              .fold<int>(0, (s, r) => s + r.amountMinor);
          final net = lent - borrowed;
          return ListView.builder(
            key: const ValueKey('loans-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top, bottom: 120),
            itemCount: items.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return SummaryBoard(
                  left: BoardStat(
                    icon: Icons.arrow_upward_rounded,
                    color: context.palette.accent,
                    label: 'Lent out',
                    value: formatMoney(lent, currency),
                  ),
                  middle: BoardStat(
                    icon: Icons.arrow_downward_rounded,
                    color: context.palette.dangerContent,
                    label: 'Borrowed',
                    value: formatMoney(borrowed, currency),
                  ),
                  rightLabel: 'Net',
                  rightValue:
                      '${net >= 0 ? '+' : '−'} ${formatMoney(net.abs(), currency)}',
                  rightColor:
                      net >= 0 ? context.palette.accent : context.palette.dangerContent,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                );
              }
              final loan = items[i - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: FadeIn(
                  key: ValueKey(loan.id),
                  child: _LoanCard(loan: loan),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}

class _LoanCard extends ConsumerWidget {
  const _LoanCard({required this.loan});
  final RecordRow loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final isBorrowed = loan.type == RecordType.loanTaken;
    final overdue = !loan.returned &&
        loan.expectedReturnAt != null &&
        loan.expectedReturnAt!.isBefore(DateTime.now());

    // Repaid-to-date comes from one grouped query shared by the whole list,
    // not a per-card watch — see loanRepaidTotalsProvider.
    final repaid =
        ref.watch(loanRepaidTotalsProvider).valueOrNull?[loan.id] ?? 0;
    final remaining = loan.amountMinor - repaid;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      // Opens the loan rather than the edit form: a loan is now a thing with a
      // repayment history, and editing it is one action inside that, the same
      // way a project works. Edit is on the detail page's app bar.
      onTap: () {
        AppHaptics.light();
        AppRoute.push(context, LoanDetailPage(initialLoan: loan));
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: context.hairline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.palette.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBorrowed
                        ? Icons.arrow_circle_down_rounded
                        : Icons.handshake_rounded,
                    size: 20,
                    color: context.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.counterparty ??
                            (isBorrowed ? 'Loan taken' : 'Loan given'),
                        style:
                            AppTextStyles.title.copyWith(color: context.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBorrowed ? 'Borrowed from' : 'Lent to',
                        style: AppTextStyles.caption
                            .copyWith(color: context.inkMuted, fontSize: 11),
                      ),
                      if (loan.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 1),
                        Text(loan.description!,
                            style: AppTextStyles.caption
                                .copyWith(color: context.inkMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedMoney(
                      minor: loan.amountMinor,
                      currency: currency,
                      style: AppTextStyles.title.copyWith(
                          color: context.ink, fontWeight: FontWeight.w700),
                    ),
                    // Only shown once something has actually been repaid — on
                    // an untouched loan the principal already says everything,
                    // and a "0 repaid" line would be noise on every card.
                    if (repaid > 0 && !loan.returned) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${formatMoney(remaining, currency)} left',
                        style: AppTextStyles.caption
                            .copyWith(color: context.palette.accent),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            XSwitcher(
              child: Row(
                key: ValueKey(loan.returned),
                children: [
                  if (loan.returned) ...[
                    _Badge(
                      text: isBorrowed ? 'Repaid' : 'Returned',
                      bg: context.palette.accentSoft,
                      fg: context.ink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                        loan.returnedAt != null
                            ? 'on ${formatShortDate(loan.returnedAt!)}'
                            : '',
                        style: AppTextStyles.caption
                            .copyWith(color: context.inkMuted)),
                  ] else ...[
                    if (loan.expectedReturnAt != null)
                      _Badge(
                        text: 'Due ${formatShortDate(loan.expectedReturnAt!)}',
                        bg: overdue
                            ? context.palette.dangerContent.withValues(alpha: 0.1)
                            : Colors.transparent,
                        fg: overdue ? context.palette.dangerContent : context.inkMuted,
                        border: !overdue,
                        borderColor: context.hairline,
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => ref
                          .read(databaseProvider)
                          .markLoanReturned(loan.id, returned: true),
                      style: TextButton.styleFrom(
                        backgroundColor: context.palette.accent,
                        foregroundColor: context.palette.onAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                      child: Text(
                        isBorrowed ? 'Mark repaid' : 'Mark returned',
                        style: AppTextStyles.caption.copyWith(
                            color: context.palette.onAccentSoft,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (loan.returned) ...[
                    const Spacer(),
                    TextButton(
                      onPressed: () => ref
                          .read(databaseProvider)
                          .markLoanReturned(loan.id, returned: false),
                      child: Text(
                        isBorrowed ? 'Undo repayment' : 'Undo',
                        style: AppTextStyles.caption.copyWith(
                            color: context.ink, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.bg,
    required this.fg,
    this.border = false,
    this.borderColor,
  });
  final String text;
  final Color bg;
  final Color fg;
  final bool border;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: border
            ? Border.all(color: borderColor ?? context.hairline)
            : null,
      ),
      child: Text(text,
          style: AppTextStyles.caption
              .copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

class _LoansFilterSheet extends ConsumerStatefulWidget {
  const _LoansFilterSheet({
    required this.initialType,
    required this.initialCategoryIds,
    required this.initialRange,
    required this.onChanged,
    required this.onReset,
  });
  final LoanTypeFilter initialType;
  final Set<String> initialCategoryIds;
  final DateRangeFilter initialRange;
  final void Function(LoanTypeFilter, Set<String>, DateRangeFilter) onChanged;
  final VoidCallback onReset;

  @override
  ConsumerState<_LoansFilterSheet> createState() => _LoansFilterSheetState();
}

class _LoansFilterSheetState extends ConsumerState<_LoansFilterSheet> {
  late LoanTypeFilter _type;
  late Set<String> _categoryIds;
  late DateRangeFilter _quickRange;
  bool _isCustom = false;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _categoryIds = {...widget.initialCategoryIds};
    if (isCustomRange(widget.initialRange)) {
      _isCustom = true;
      final r = widget.initialRange.resolve(DateTime.now());
      _customStart = r.start;
      _customEnd = r.end;
      _quickRange = DateRangeFilter.all;
    } else {
      _quickRange = widget.initialRange;
    }
  }

  DateRangeFilter get _effectiveRange {
    if (_isCustom && _customStart != null && _customEnd != null) {
      return DateRangeFilter.custom(_customStart!, _customEnd!);
    }
    return _quickRange;
  }

  bool get _hasActiveFilters =>
      _type != LoanTypeFilter.all ||
      _categoryIds.isNotEmpty ||
      _isCustom ||
      _quickRange != DateRangeFilter.all;

  void _notify() => widget.onChanged(_type, _categoryIds, _effectiveRange);

  void _reset() {
    setState(() {
      _type = LoanTypeFilter.all;
      _categoryIds = {};
      _quickRange = DateRangeFilter.all;
      _isCustom = false;
      _customStart = null;
      _customEnd = null;
    });
    widget.onReset();
  }

  Future<void> _addCategory(List<CategoryRow> cats) async {
    String inputText = '';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(hintText: 'e.g. Family, Work'),
          onChanged: (v) => inputText = v,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.accent,
              foregroundColor: context.palette.onAccent,
            ),
            onPressed: () => Navigator.pop(ctx, inputText.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final existing =
        cats.where((c) => c.name.toLowerCase() == name.toLowerCase());
    if (existing.isNotEmpty) {
      setState(() => _categoryIds = {..._categoryIds, existing.first.id});
      _notify();
      return;
    }
    final row = await ref.read(databaseProvider).addCategory(name);
    if (!mounted) return;
    setState(() => _categoryIds = {..._categoryIds, row.id});
    _notify();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_customStart ?? now)
        : (_customEnd ?? _customStart ?? now);
    final firstDate =
        isStart ? DateTime(2020) : (_customStart ?? DateTime(2020));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: firstDate,
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
        if (_customEnd != null && _customEnd!.isBefore(picked)) {
          _customEnd = null;
        }
      } else {
        _customEnd = picked;
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];

    return GlassSheet(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text('Filter Loans',
                      style: AppTextStyles.headline
                          .copyWith(color: context.ink)),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _hasActiveFilters ? 1.0 : 0.0,
                    duration: AppMotion.fast,
                    child: GestureDetector(
                      onTap: _hasActiveFilters ? _reset : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.hairline,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.refresh_rounded,
                            size: 18, color: context.ink),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Type ──────────────────────────────────────────────────────
              _sectionLabel('Type'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    label: 'All',
                    selected: _type == LoanTypeFilter.all,
                    onTap: () {
                      setState(() => _type = LoanTypeFilter.all);
                      _notify();
                    },
                  ),
                  _Chip(
                    label: 'Lent out',
                    selected: _type == LoanTypeFilter.lent,
                    onTap: () {
                      setState(() => _type = LoanTypeFilter.lent);
                      _notify();
                    },
                  ),
                  _Chip(
                    label: 'Borrowed',
                    selected: _type == LoanTypeFilter.borrowed,
                    onTap: () {
                      setState(() => _type = LoanTypeFilter.borrowed);
                      _notify();
                    },
                  ),
                ],
              ),

              // ── Category ──────────────────────────────────────────────────
              const SizedBox(height: 20),
              _sectionLabel('Category'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (cats.isNotEmpty)
                    _Chip(
                      label: 'All',
                      selected: _categoryIds.isEmpty,
                      onTap: () {
                        setState(_categoryIds.clear);
                        _notify();
                      },
                    ),
                  for (final cat in cats)
                    _Chip(
                      label: cat.name,
                      selected: _categoryIds.contains(cat.id),
                      onTap: () {
                        setState(() => _categoryIds.contains(cat.id)
                            ? _categoryIds.remove(cat.id)
                            : _categoryIds.add(cat.id));
                        _notify();
                      },
                    ),
                  _AddChip(onTap: () => _addCategory(cats)),
                ],
              ),

              // ── Date range ────────────────────────────────────────────────
              const SizedBox(height: 20),
              _sectionLabel('Date Range'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    label: 'All',
                    selected: !_isCustom && _quickRange == DateRangeFilter.all,
                    onTap: () {
                      setState(() {
                        _isCustom = false;
                        _quickRange = DateRangeFilter.all;
                      });
                      _notify();
                    },
                  ),
                  _Chip(
                    label: '1W',
                    selected:
                        !_isCustom && _quickRange == DateRangeFilter.week,
                    onTap: () {
                      setState(() {
                        _isCustom = false;
                        _quickRange = DateRangeFilter.week;
                      });
                      _notify();
                    },
                  ),
                  _Chip(
                    label: '1M',
                    selected:
                        !_isCustom && _quickRange == DateRangeFilter.month,
                    onTap: () {
                      setState(() {
                        _isCustom = false;
                        _quickRange = DateRangeFilter.month;
                      });
                      _notify();
                    },
                  ),
                  _Chip(
                    label: '1Y',
                    selected:
                        !_isCustom && _quickRange == DateRangeFilter.year,
                    onTap: () {
                      setState(() {
                        _isCustom = false;
                        _quickRange = DateRangeFilter.year;
                      });
                      _notify();
                    },
                  ),
                  _Chip(
                    label: 'Custom',
                    selected: _isCustom,
                    onTap: () {
                      setState(() => _isCustom = !_isCustom);
                      _notify();
                    },
                  ),
                ],
              ),

              AnimatedSize(
                duration: AppMotion.med,
                curve: AppMotion.enter,
                alignment: Alignment.topCenter,
                child: _isCustom
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _DateTile(
                                label: 'From',
                                date: _customStart,
                                onTap: () => _pickDate(isStart: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateTile(
                                label: 'To',
                                date: _customEnd,
                                onTap: () => _pickDate(isStart: false),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTextStyles.title.copyWith(color: context.ink),
      );
}

// ── Chips / date tile (local copies, matching Records/Projects) ────────────────

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.ink : Colors.transparent,
          border: Border.all(
            color: selected ? context.ink : context.hairline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? context.surface : context.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: context.hairline, width: 1.5),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: context.inkSubtle),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: AppTextStyles.caption.copyWith(
                color: context.inkSubtle,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile(
      {required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.hairline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: context.inkMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: context.inkSubtle),
                const SizedBox(width: 6),
                Text(
                  date != null ? formatShortDate(date!) : 'Select',
                  style: AppTextStyles.body.copyWith(
                      color: date != null ? context.ink : context.inkSubtle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
