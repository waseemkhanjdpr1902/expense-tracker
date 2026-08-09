import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics.dart';
import '../../../core/icons.dart';
import '../../../core/hero.dart';
import '../../../core/currency.dart';
import '../../../core/date_range.dart';
import '../../../core/formatters.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../data/settings_repo.dart';
import '../../shared/app_sheet.dart';
import '../../shared/empty_state.dart';
import '../../shared/loading.dart';
import '../../shared/totals_strip.dart';
import '../widgets/record_tile.dart';
import '../../../core/debounce.dart';
import '../../../core/search_text.dart';
import '../../search/data/search_providers.dart';
import '../../search/ui/searchable_app_bar.dart';
import 'add_record_sheet.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

class RecordsListPage extends ConsumerStatefulWidget {
  const RecordsListPage({super.key});

  @override
  ConsumerState<RecordsListPage> createState() => _RecordsListPageState();
}

class _RecordsListPageState extends ConsumerState<RecordsListPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

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

  /// Last good data, kept so an autoDispose reload doesn't flash a spinner on
  /// every keystroke.
  List<RecordRow>? _lastItems;
  RecordsTotals? _lastTotals;

  RecordsFilter _filter = RecordsFilter.all;
  DateRangeFilter _range = DateRangeFilter.month;
  /// A Set, not a single id: categories are multi-select. Empty == no
  /// category filter, which is why 'All' is simply the empty selection
  /// rather than a sentinel value.
  Set<String> _selectedCategoryIds = {};

  // Pagination
  static const _pageSize = 50;
  int _limit = _pageSize;
  // Tracks last emitted count so the scroll listener can decide whether to
  // fetch more without needing a setState (safe direct mutation in build).
  int _lastCount = 0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce.dispose();
    _searchAnim.dispose();
    // Never leave a stale back-interceptor pointing at a dead State.
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
    setState(() {
      _query = null;
      _limit = _pageSize;
    });
    _closeSearch();
  }

  void _setQuery(String raw) {
    final next = normalizeQuery(raw);
    if (next == _query) return;
    setState(() {
      _query = next;
      _limit = _pageSize; // a new query restarts pagination
    });
  }

  void _onScroll() {
    // Only trigger when the last batch was full — if fewer came back we're done.
    if (_lastCount < _limit) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      setState(() => _limit += _pageSize);
    }
  }

  bool get _hasActiveFilters =>
      _filter != RecordsFilter.all ||
      _selectedCategoryIds.isNotEmpty ||
      _range != DateRangeFilter.month;

  void _openFilterSheet() {
    AppSheet.show(
      context,
      transparent: true,
      builder: (_) => _FilterSheet(
        initialType: _filter,
        initialCategoryIds: _selectedCategoryIds,
        initialRange: _range,
        onChanged: (type, categoryIds, range) {
          setState(() {
            _filter = type;
            _selectedCategoryIds = categoryIds;
            _range = range;
            _limit = _pageSize; // reset pagination on filter change
          });
        },
        onReset: () => setState(() {
          _filter = RecordsFilter.all;
          _selectedCategoryIds = {};
          _range = DateRangeFilter.month;
          _limit = _pageSize; // reset pagination on filter reset
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Deep-link from global search: arrive with the query already applied and
    // the field open.
    // Deep-link from global search. Uses `watch`, not `listen`: the shell's
    // PageView builds pages lazily, so a page that had never been built yet
    // would miss the change entirely — `listen` only fires on transitions
    // observed while already listening. Applying post-frame (setState is
    // illegal during build) and clearing the provider makes this run once.
    final pending = ref.watch(pendingSearchProvider);
    if (pending != null && pending.tab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _query = pending.query;
          _searchController.text = pending.query;
          if (pending.recordsType != null) _filter = pending.recordsType!;
          if (pending.categoryId != null) {
            _selectedCategoryIds = {pending.categoryId!};
          }
          _limit = _pageSize;
        });
        _searchAnim.value = 1;
        ref.read(searchBackInterceptorProvider.notifier).state = _closeSearch;
        ref.read(pendingSearchProvider.notifier).state = null;
      });
    }

    final records = ref.watch(filteredRecordsProvider(RecordsQuery(
      type: _filter,
      range: _range,
      categoryIds: categoryKey(_selectedCategoryIds),
      limit: _limit,
      query: _query,
    )));
    final currency = ref.watch(currencyProvider);
    // Unlimited, so the board stays exact regardless of pagination — and it
    // carries the same query so list and totals can never disagree.
    final totals = ref.watch(filteredTotalsProvider(RecordsTotalsQuery(
      type: _filter,
      range: _range,
      categoryIds: categoryKey(_selectedCategoryIds),
      query: _query,
    )));
    if (records.hasValue) _lastItems = records.value;
    if (totals.hasValue) _lastTotals = totals.value;

    // Changing the query changes the autoDispose family key, which means a
    // brand-new provider starting in AsyncLoading — a spinner flash on every
    // keystroke. Substitute the last good value and dim instead.
    final effectiveRecords = records.hasValue
        ? records
        : (_lastItems != null
            ? AsyncData<List<RecordRow>>(_lastItems!)
            : records);
    final effectiveTotals = totals.hasValue
        ? totals
        : (_lastTotals != null
            ? AsyncData<RecordsTotals>(_lastTotals!)
            : totals);
    final isStale = records.isLoading && _lastItems != null;

    return Scaffold(
      // Content passes beneath the glass bar; without this the bar has
      // nothing to blur and the effect is an expensive flat fill.
      extendBodyBehindAppBar: true,
      appBar: SearchableAppBar(
        reduceGlass: ref.watch(reduceTransparencyProvider),
        title: 'Records',
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
            onPressed: _openFilterSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded),
                if (_hasActiveFilters)
                  Positioned(
                    right: -2,
                    top: -2,
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
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => openAddRecordSheet(context),
          ),
        ],
      ),
      body: HeroScope(
        name: 'records',
        child: SafeArea(
        // top: false — the list applies the inset itself as padding, so
        // rows scroll *under* the bar instead of stopping below it.
        top: false,
        bottom: false,
        child: RefreshIndicator(
          color: context.palette.accent,
          onRefresh: () async {
            ref.invalidate(filteredRecordsProvider);
            ref.invalidate(filteredTotalsProvider);
            await ref.read(filteredRecordsProvider(RecordsQuery(
              type: _filter,
              range: _range,
              categoryIds: categoryKey(_selectedCategoryIds),
              limit: _limit,
            )).future);
          },
          child: AnimatedOpacity(
            opacity: isStale ? 0.55 : 1,
            duration: AppMotion.fast,
            child: XSwitcher(
          child: effectiveRecords.when(
            skipLoadingOnReload: true,
            loading: () => const DelayedVisible(
                key: ValueKey('rec-loading'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: SkeletonRows(),
                )),
            error: (e, _) =>
                Center(key: const ValueKey('rec-error'), child: Text('$e')),
            data: (items) {
              // Track count for scroll listener (safe direct mutation — no rebuild).
              _lastCount = items.length;

              if (items.isEmpty) {
                return EmptyState(
                  icon: _query != null
                      ? AppIcons.noResults
                      : AppIcons.records,
                  title: _query != null
                      ? 'No records match "$_query"'
                      : _hasActiveFilters
                          ? 'No records here'
                          : 'No records yet',
                  message: _query != null
                      ? 'Try a different word or clear the search.'
                      : _hasActiveFilters
                          ? 'Try adjusting your filters.'
                          : 'Track your first expense or income.',
                  actionLabel: (_query == null && !_hasActiveFilters)
                      ? 'Add a record'
                      : null,
                  onAction: (_query == null && !_hasActiveFilters)
                      ? () => openAddRecordSheet(context)
                      : null,
                ).scrollable(context);
              }

              final groups = _groupByDay(items);
              final mayHaveMore = items.length >= _limit;

              return ListView.builder(
                key: const ValueKey('rec-list'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top, bottom: 120),
                itemCount: groups.length + 2,
                itemBuilder: (_, i) {
                  // ── Totals strip (index 0) ────────────────────────────────
                  if (i == 0) {
                    return effectiveTotals.maybeWhen(
                      data: (t) => t.incomeMinor == 0 && t.expenseMinor == 0
                          ? const SizedBox.shrink()
                          : _recordsBoard(context, t, currency),
                      orElse: () => const SizedBox.shrink(),
                    );
                  }

                  // ── Footer (last index) ───────────────────────────────────
                  if (i == groups.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: mayHaveMore
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.palette.accent,
                                ),
                              )
                            : Text(
                                '${items.length} record${items.length == 1 ? '' : 's'} total',
                                style: AppTextStyles.caption
                                    .copyWith(color: context.inkSubtle),
                              ),
                      ),
                    );
                  }

                  // ── Day group (shifted by 1) ──────────────────────────────
                  final g = groups[i - 1];
                  final dayNet = g.items.fold<int>(
                    0,
                    (s, r) => s +
                        (r.type == RecordType.income
                            ? r.amountMinor
                            : r.type == RecordType.expense
                                ? -r.amountMinor
                                : 0),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formatDayHeader(g.day).toUpperCase(),
                                style: AppTextStyles.overline
                                    .copyWith(color: context.inkSubtle)),
                            if (dayNet != 0)
                              Text(
                                '${dayNet > 0 ? '+' : '−'} ${formatMoney(dayNet.abs(), currency)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: dayNet > 0
                                      ? context.palette.accent
                                      : context.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final r in g.items)
                        FadeIn(
                          key: ValueKey('fade-${r.id}'),
                          child: Dismissible(
                            key: ValueKey(r.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color:
                                  context.palette.dangerContent.withValues(alpha: 0.1),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: context.palette.dangerContent),
                            ),
                            confirmDismiss: (_) async =>
                                await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete record?'),
                                    content: const Text(
                                        'This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: context.palette.danger,
                                              foregroundColor:
                                                  context.palette.onDanger),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete')),
                                    ],
                                  ),
                                ) ??
                                false,
                            onDismissed: (_) =>
                                {
                              AppHaptics.warning(),
                              ref.read(databaseProvider).deleteRecord(r.id),
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              child:
                                  RecordTile(record: r, currency: currency),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          ),
          ),
        ),
      ),
      ),
    );
  }

  List<_DayGroup> _groupByDay(List<RecordRow> items) {
    final map = <DateTime, List<RecordRow>>{};
    for (final r in items) {
      final d =
          DateTime(r.occurredAt.year, r.occurredAt.month, r.occurredAt.day);
      map.putIfAbsent(d, () => []).add(r);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) _DayGroup(k, map[k]!)];
  }
}

class _DayGroup {
  final DateTime day;
  final List<RecordRow> items;
  _DayGroup(this.day, this.items);
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({
    required this.initialType,
    required this.initialCategoryIds,
    required this.initialRange,
    required this.onChanged,
    required this.onReset,
  });
  final RecordsFilter initialType;
  final Set<String> initialCategoryIds;
  final DateRangeFilter initialRange;
  final void Function(RecordsFilter, Set<String>, DateRangeFilter) onChanged;
  final VoidCallback onReset;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late RecordsFilter _type;
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
      _quickRange = DateRangeFilter.month;
    } else {
      _quickRange = widget.initialRange;
    }
  }

  DateRangeFilter get _effectiveRange {
    if (_isCustom && _customStart != null && _customEnd != null) {
      return DateRangeFilter.custom(_customStart!, _customEnd!);
    }
    return _isCustom ? _quickRange : _quickRange;
  }

  bool get _hasActiveFilters =>
      _type != RecordsFilter.all ||
      _categoryIds.isNotEmpty ||
      _isCustom ||
      _quickRange != DateRangeFilter.month;

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
              const InputDecoration(hintText: 'e.g. Food, Transport'),
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
      widget.onChanged(_type, _categoryIds, _effectiveRange);
      return;
    }
    final row = await ref.read(databaseProvider).addCategory(name);
    if (!mounted) return;
    setState(() => _categoryIds = {..._categoryIds, row.id});
    widget.onChanged(_type, _categoryIds, _effectiveRange);
  }

  void _notify() =>
      widget.onChanged(_type, _categoryIds, _effectiveRange);

  void _reset() {
    setState(() {
      _type = RecordsFilter.all;
      _categoryIds = {};
      _quickRange = DateRangeFilter.month;
      _isCustom = false;
      _customStart = null;
      _customEnd = null;
    });
    widget.onReset();
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
              // Drag handle
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

              // Title row + reset icon
              Row(
                children: [
                  Text('Filter Records',
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
                    selected: _type == RecordsFilter.all,
                    onTap: () {
                      setState(() => _type = RecordsFilter.all);
                      _notify();
                    },
                  ),
                  _Chip(
                    label: 'Income',
                    selected: _type == RecordsFilter.incomeOnly,
                    onTap: () {
                      setState(() => _type = RecordsFilter.incomeOnly);
                      _notify();
                    },
                  ),
                  _Chip(
                    label: 'Expense',
                    selected: _type == RecordsFilter.expenseOnly,
                    onTap: () {
                      setState(() => _type = RecordsFilter.expenseOnly);
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

              // ── Custom date pickers ────────────────────────────────────────
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

// ── Chip ──────────────────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          // Selected = ink (black in light, white in dark), unselected = transparent
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
            // Flip: selected text = surface (white in light, dark in dark)
            color: selected ? context.surface : context.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Add-category chip ─────────────────────────────────────────────────────────

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

// ── Date picker tile ──────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    color:
                        date != null ? context.ink : context.inkSubtle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Totals strip ──────────────────────────────────────────────────────────────

Widget _recordsBoard(
    BuildContext context, RecordsTotals totals, CurrencyOption currency) {
  final net = totals.netMinor;
  return SummaryBoard(
    left: BoardStat(
      icon: Icons.arrow_downward_rounded,
      color: context.palette.accent,
      label: 'Income',
      value: formatMoney(totals.incomeMinor, currency),
    ),
    middle: BoardStat(
      icon: Icons.arrow_upward_rounded,
      color: context.palette.dangerContent,
      label: 'Expense',
      value: formatMoney(totals.expenseMinor, currency),
    ),
    rightLabel: 'Net',
    rightValue:
        '${net >= 0 ? '+' : '−'} ${formatMoney(net.abs(), currency)}',
    rightColor: net >= 0 ? context.palette.accent : context.palette.dangerContent,
  );
}
