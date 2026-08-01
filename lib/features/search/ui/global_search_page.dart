import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency.dart';
import '../../../core/debounce.dart';
import '../../../core/hero.dart';
import '../../../core/motion.dart';
import '../../../core/search_text.dart';
import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../data/settings_repo.dart';
import '../../../shell/home_shell.dart';
import '../../projects/ui/project_detail_page.dart';
import '../../records/widgets/record_tile.dart';
import '../../shared/empty_state.dart';
import '../../../core/icons.dart';
import '../../shared/section_header.dart';
import '../data/search_providers.dart';
import 'widgets/search_result_row.dart';

/// Global search across records, loans, projects and categories.
///
/// A long-lived page `State` owns the controller and focus node — the codebase
/// forbids controllers in transient overlays (see the crash documented at
/// `record_form_page.dart:260`).
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  /// Fetch one more than we show so "there are more" needs no COUNT(*).
  static const _kShow = 4;
  static const _kFetch = _kShow + 1;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _debounce = Debouncer();

  /// Debounced, normalised query actually driving the providers.
  String? _query;

  @override
  void initState() {
    super.initState();
    // Focus after the reveal finishes, so the keyboard follows the surface
    // instead of racing it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anim = ModalRoute.of(context)?.animation;
      if (anim == null || anim.isCompleted) {
        _focus.requestFocus();
        return;
      }
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          anim.removeStatusListener(listener);
          if (mounted) _focus.requestFocus();
        }
      }

      anim.addStatusListener(listener);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce(() {
      if (!mounted) return;
      final next = normalizeQuery(raw);
      if (next != _query) setState(() => _query = next);
    });
  }

  void _clear() {
    _controller.clear();
    _debounce.cancel();
    setState(() => _query = null);
    _focus.requestFocus();
  }

  /// Dismiss the keyboard before popping, or the keyboard slide and the
  /// shrink animation fight each other.
  Future<void> _close() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) Navigator.of(context).pop();
  }

  /// Hand the query to a shell tab, then leave. Provider first so the
  /// destination (kept alive) sees it on its very next build.
  void _seeAll({required int tab, RecordsFilter? type, String? categoryId}) {
    final q = _query;
    if (q == null) return;
    ref.read(pendingSearchProvider.notifier).state = PendingSearch(
      tab: tab,
      query: q,
      recordsType: type,
      categoryId: categoryId,
    );
    Navigator.of(context).pop();
    ref.read(shellNavProvider.notifier).goTo(tab);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: context.surface,
        // The keyboard must not resize this Scaffold mid-transition, or the
        // target rect moves and the reveal stutters.
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _SearchField(
                controller: _controller,
                focusNode: _focus,
                onChanged: _onChanged,
                onSubmitted: (raw) => _debounce.flush(() {
                  if (mounted) setState(() => _query = normalizeQuery(raw));
                }),
                onBack: _close,
                onClear: _clear,
                hasText: _controller.text.isNotEmpty,
              ),
              Divider(height: 1, color: context.hairline),
              Expanded(
                child: XSwitcher(
                  child: query == null
                      ? const _InitialState(key: ValueKey('search-initial'))
                      : _Results(
                          key: ValueKey('search-results-$query'),
                          query: query,
                          show: _kShow,
                          fetch: _kFetch,
                          onSeeAll: _seeAll,
                          onNavigate: _close,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Field ────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBack,
    required this.onClear,
    required this.hasText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final bool hasText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, AppSpacing.sm, 8, AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close search',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.body.copyWith(color: context.ink),
              decoration: InputDecoration(
                hintText: 'Search everything…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle:
                    AppTextStyles.body.copyWith(color: context.inkSubtle),
              ),
            ),
          ),
          XSwitcher(
            duration: AppMotion.fast,
            child: hasText
                ? IconButton(
                    key: const ValueKey('clear'),
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClear,
                  )
                : const SizedBox(width: 48, key: ValueKey('no-clear')),
          ),
        ],
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _InitialState extends StatelessWidget {
  const _InitialState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 40, color: context.inkSubtle),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Search records, loans,\nprojects and categories',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: context.inkMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try a name, a note or a category',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: context.inkSubtle),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results ──────────────────────────────────────────────────────────────────

class _Results extends ConsumerWidget {
  const _Results({
    super.key,
    required this.query,
    required this.show,
    required this.fetch,
    required this.onSeeAll,
    required this.onNavigate,
  });

  final String query;
  final int show;
  final int fetch;
  final void Function({required int tab, RecordsFilter? type, String? categoryId})
      onSeeAll;
  final VoidCallback onNavigate;

  List<RecordRow> _records(WidgetRef ref, Set<RecordType> types) =>
      ref
          .watch(recordSearchProvider(
              RecordSearchQuery(query: query, types: types, limit: fetch)))
          .valueOrNull ??
      const [];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);

    final expenses = _records(ref, const {RecordType.expense});
    final income = _records(ref, const {RecordType.income});
    final loans =
        _records(ref, const {RecordType.loanGiven, RecordType.loanTaken});
    final projects = ref.watch(projectSearchProvider(query));
    final categories = ref.watch(categorySearchProvider(query));

    if (expenses.isEmpty &&
        income.isEmpty &&
        loans.isEmpty &&
        projects.isEmpty &&
        categories.isEmpty) {
      return EmptyState(
        key: ValueKey('empty-$query'),
        icon: AppIcons.noResults,
        compact: true,
        title: 'No matches for "$query"',
        message: 'Try a shorter word, a person\u2019s name, or a category.',
      );
    }

    Widget recordSection(
      String label,
      List<RecordRow> items, {
      required int tab,
      RecordsFilter? type,
    }) =>
        _Section(
          label: label,
          hasMore: items.length > show,
          onSeeAll: () => onSeeAll(tab: tab, type: type),
          children: [
            for (final r in items.take(show))
              RecordTile(record: r, currency: currency, highlight: query),
          ],
        );

    // One delay per section, not per row — five staggered groups read as
    // considered; twenty staggered rows read as a slot machine.
    final sections = <Widget>[
      if (expenses.isNotEmpty)
        recordSection('Expenses', expenses,
            tab: 1, type: RecordsFilter.expenseOnly),
      if (income.isNotEmpty)
        recordSection('Income', income, tab: 1, type: RecordsFilter.incomeOnly),
      if (loans.isNotEmpty) recordSection('Loans', loans, tab: 2),
      if (projects.isNotEmpty)
        _Section(
          label: 'Projects',
          hasMore: projects.length > show,
          onSeeAll: () => onSeeAll(tab: 3),
          children: [
            for (final p in projects.take(show))
              SearchResultRow(
                icon: Icons.folder_rounded,
                title: p.name,
                subtitle: p.description,
                trailing: formatMoney(p.totalAmountMinor, currency),
                highlight: query,
                onTap: () {
                  onNavigate();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProjectDetailPage(initialProject: p),
                  ));
                },
              ),
          ],
        ),
      if (categories.isNotEmpty)
        _Section(
          label: 'Categories',
          hasMore: false,
          onSeeAll: null,
          children: [
            for (final c in categories.take(show))
              SearchResultRow(
                icon: Icons.sell_rounded,
                title: c.name,
                subtitle: 'Category',
                highlight: query,
                tint: true,
                onTap: () => onSeeAll(tab: 1, categoryId: c.id),
              ),
          ],
        ),
    ];

    return HeroScope(
      name: 'search',
      child: ListView.builder(
      // The Scaffold deliberately does not resize for the keyboard (that would
      // move the reveal's target rect mid-transition), so the inset has to be
      // added here or the last results sit underneath it.
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: 120 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      itemCount: sections.length,
      itemBuilder: (_, i) => FadeIn(
        // The query in the key is load-bearing: FadeIn animates on an element's
        // first build, so without it the stagger plays once and never again.
        key: ValueKey('sec-$i-$query'),
        delay: AppMotion.staggerDelay(i),
        offset: 4,
        child: sections[i],
      ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.children,
    required this.hasMore,
    required this.onSeeAll,
  });

  final String label;
  final List<Widget> children;
  final bool hasMore;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
          child: SectionHeader(
            label,
            trailing: (hasMore && onSeeAll != null)
                ? GestureDetector(
                    onTap: onSeeAll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('See all',
                            style: AppTextStyles.caption.copyWith(
                                color: context.ink,
                                fontWeight: FontWeight.w700)),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: context.inkSubtle),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        ...children,
      ],
    );
  }
}
