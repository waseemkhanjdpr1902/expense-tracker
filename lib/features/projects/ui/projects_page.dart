import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../shared/loading.dart';
import '../../shared/empty_state.dart';
import '../../../core/icons.dart';
import '../../../core/routes.dart';
import '../../shared/totals_strip.dart';
import 'project_detail_page.dart';
import 'project_form_page.dart';
import '../../../core/debounce.dart';
import '../../../core/search_text.dart';
import '../../search/data/search_providers.dart';
import '../../search/ui/searchable_app_bar.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage>
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce.dispose();
    _searchAnim.dispose();
    ref.read(searchBackInterceptorProvider.notifier).state = null;
    super.dispose();
  }

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

  /// Multi-select: empty means no category filter.
  Set<String> _categoryIds = {};
  DateRangeFilter _range = DateRangeFilter.all;
  ProjectStatusFilter _status = ProjectStatusFilter.ongoing;

  // "Active" means "differs from the defaults" — both new defaults must appear
  // here or a fresh launch shows the green dot permanently.
  bool get _hasActiveFilters =>
      _categoryIds.isNotEmpty ||
      _range != DateRangeFilter.all ||
      _status != ProjectStatusFilter.ongoing;

  void _openFilterSheet() {
    AppSheet.show(
      context,
      transparent: true,
      builder: (_) => _ProjectFilterSheet(
        initialCategoryIds: _categoryIds,
        initialRange: _range,
        initialStatus: _status,
        onChanged: (categoryIds, range, status) {
          setState(() {
            _categoryIds = categoryIds;
            _range = range;
            _status = status;
          });
        },
        onReset: () => setState(() {
          _categoryIds = {};
          _range = DateRangeFilter.all;
          _status = ProjectStatusFilter.ongoing;
        }),
      ),
    );
  }

  List<ProjectRow> _applyFilters(List<ProjectRow> all) {
    // Null range = no date bound at all (the "All" chip).
    final resolved = _range.resolveOrNull(DateTime.now());
    final q = normalizeQuery(_query)?.toLowerCase();
    return all.where((p) {
      if (_categoryIds.isNotEmpty && !_categoryIds.contains(p.categoryId)) {
        return false;
      }
      switch (_status) {
        case ProjectStatusFilter.ongoing:
          if (p.completedAt != null) return false;
        case ProjectStatusFilter.completed:
          if (p.completedAt == null) return false;
        case ProjectStatusFilter.all:
          break;
      }
      if (resolved != null &&
          (p.startDate.isBefore(resolved.start) ||
              p.startDate.isAfter(resolved.end))) {
        return false;
      }
      if (q != null &&
          !'${p.name} ${p.description ?? ''}'.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
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
    if (pending != null && pending.tab == 3) {
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

    final projectsAsync = ref.watch(projectsProvider);
    final currency = ref.watch(currencyProvider);
    final received =
        ref.watch(receivedByProjectProvider).valueOrNull ?? const {};
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SearchableAppBar(
        title: 'Projects',
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
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ProjectFormPage(),
            )),
          ),
        ],
      ),
      body: HeroScope(
        name: 'projects',
        child: SafeArea(
        // top: false — the list applies the inset itself as padding, so
        // cards scroll *under* the bar instead of stopping below it.
        top: false,
        bottom: false,
        child: RefreshIndicator(
          color: context.palette.accent,
          onRefresh: () async {
            ref.invalidate(projectsProvider);
            ref.invalidate(receivedByProjectProvider);
            await ref.read(projectsProvider.future);
          },
          child: XSwitcher(
          child: projectsAsync.when(
            loading: () => const DelayedVisible(
                key: ValueKey('proj-loading'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SkeletonRows(rows: 4),
                )),
            error: (e, _) =>
                Center(key: const ValueKey('proj-error'), child: Text('$e')),
            data: (all) {
              final items = _applyFilters(all);
              if (all.isEmpty) {
                return EmptyState(
                  icon: AppIcons.projects,
                  title: 'No projects yet',
                  message: 'Track a project budget and its payments.',
                  actionLabel: 'New project',
                  onAction: () => AppRoute.push(
                      context, const ProjectFormPage(), modal: true),
                ).scrollable(context);
              }
              if (items.isEmpty) {
                return EmptyState(
                  icon: _query != null
                      ? AppIcons.noResults
                      : AppIcons.noFilterMatch,
                  title: _query != null
                      ? 'No projects match "$_query"'
                      : 'No projects match',
                  message: 'Try adjusting your filters.',
                ).scrollable(context);
              }
              final budget =
                  items.fold<int>(0, (s, p) => s + p.totalAmountMinor);
              final receivedTotal = items.fold<int>(
                  0, (s, p) => s + (received[p.id] ?? 0));
              final remaining = budget - receivedTotal;
              return ListView.builder(
                key: const ValueKey('proj-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                // Status bar inset *plus* the toolbar: cards still scroll under
                // the glass bar, but at rest the first one clears it.
                padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                    bottom: 120),
                itemCount: items.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return SummaryBoard(
                      left: BoardStat(
                        icon: Icons.account_balance_wallet_rounded,
                        color: context.ink,
                        label: 'Budget',
                        value: formatMoney(budget, currency),
                      ),
                      middle: BoardStat(
                        icon: Icons.arrow_downward_rounded,
                        color: context.palette.accent,
                        label: 'Received',
                        value: formatMoney(receivedTotal, currency),
                      ),
                      rightLabel: 'Remaining',
                      rightValue: formatMoney(remaining, currency),
                      rightColor: remaining <= 0
                          ? context.palette.accent
                          : context.ink,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    );
                  }
                  final project = items[i - 1];
                  // Paid comes from the page's existing grouped-sum stream —
                  // no per-card subscription, and it can never disagree with
                  // the summary board above.
                  final catName = cats
                      .where((c) => c.id == project.categoryId)
                      .map((c) => c.name)
                      .firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: FadeIn(
                      key: ValueKey(project.id),
                      child: _CardShell(
                        project: project,
                        catName: catName,
                        currency: currency,
                        paidMinor: received[project.id] ?? 0,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailPage(initialProject: project),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          ),
        ),
        ),
      ),
    );
  }
}

// ── Project card ──────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.project,
    required this.catName,
    required this.onTap,
    required this.currency,
    required this.paidMinor,
  });
  final ProjectRow project;
  final String? catName;
  final VoidCallback onTap;
  final CurrencyOption currency;
  final int paidMinor;

  @override
  Widget build(BuildContext context) {
    // Guard the divide: a zero-budget project would yield NaN and trip
    // LinearProgressIndicator's assert.
    final progress = project.totalAmountMinor > 0
        ? (paidMinor / project.totalAmountMinor).clamp(0.0, 1.0)
        : 0.0;
    final isDone = paidMinor >= project.totalAmountMinor;
    final remaining = project.totalAmountMinor - paidMinor;
    final remainingLabel = remaining > 0
        ? '${formatMoney(remaining, currency)} remaining'
        : remaining == 0
            ? 'Fully paid'
            : '${formatMoney(-remaining, currency)} extra';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.cardSurface,
          border: Border.all(color: context.hairline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name,
                          style: AppTextStyles.title
                              .copyWith(color: context.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (project.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(project.description!,
                            style: AppTextStyles.caption
                                .copyWith(color: context.inkMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (catName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.palette.accentSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(catName!,
                        style: AppTextStyles.caption.copyWith(
                            color: context.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: context.hairline,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.palette.accent),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatMoney(paidMinor, currency)} paid',
                  style: AppTextStyles.caption.copyWith(
                      color: isDone ? context.palette.accent : context.inkMuted),
                ),
                Text(
                  'of ${formatMoney(project.totalAmountMinor, currency)}',
                  style: AppTextStyles.caption
                      .copyWith(color: context.inkSubtle),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Right-aligned so it reads as a continuation of "of <total>".
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                remainingLabel,
                style: AppTextStyles.caption.copyWith(
                  color: remaining <= 0 ? context.palette.accent : context.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (project.endDate != null) ...[
              const SizedBox(height: 6),
              Text(
                '${formatShortDate(project.startDate)} → ${formatShortDate(project.endDate!)}',
                style: AppTextStyles.caption
                    .copyWith(color: context.inkSubtle, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

class _ProjectFilterSheet extends ConsumerStatefulWidget {
  const _ProjectFilterSheet({
    required this.initialCategoryIds,
    required this.initialRange,
    required this.initialStatus,
    required this.onChanged,
    required this.onReset,
  });
  final Set<String> initialCategoryIds;
  final DateRangeFilter initialRange;
  final ProjectStatusFilter initialStatus;
  final void Function(Set<String>, DateRangeFilter, ProjectStatusFilter)
      onChanged;
  final VoidCallback onReset;

  @override
  ConsumerState<_ProjectFilterSheet> createState() =>
      _ProjectFilterSheetState();
}

class _ProjectFilterSheetState extends ConsumerState<_ProjectFilterSheet> {
  late Set<String> _categoryIds;
  late DateRangeFilter _quickRange;
  late ProjectStatusFilter _status;
  bool _isCustom = false;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _categoryIds = {...widget.initialCategoryIds};
    _status = widget.initialStatus;
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
      _categoryIds.isNotEmpty ||
      _isCustom ||
      _quickRange != DateRangeFilter.all ||
      _status != ProjectStatusFilter.ongoing;

  void _notify() =>
      widget.onChanged(_categoryIds, _effectiveRange, _status);

  void _reset() {
    setState(() {
      _categoryIds = {};
      _status = ProjectStatusFilter.ongoing;
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
              const InputDecoration(hintText: 'e.g. Construction, IT'),
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
      lastDate: DateTime(2040),
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

              // Title + reset
              Row(
                children: [
                  Text('Filter Projects',
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

              // ── Status ────────────────────────────────────────────────────
              _sectionLabel('Status'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, value) in const [
                    ('All', ProjectStatusFilter.all),
                    ('Ongoing', ProjectStatusFilter.ongoing),
                    ('Completed', ProjectStatusFilter.completed),
                  ])
                    _Chip(
                      label: label,
                      selected: _status == value,
                      onTap: () {
                        setState(() => _status = value);
                        _notify();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Category ──────────────────────────────────────────────────
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
              _sectionLabel('Start Date Range'),
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

              // Custom date pickers
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

  Widget _sectionLabel(String text) =>
      Text(text, style: AppTextStyles.title.copyWith(color: context.ink));
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
