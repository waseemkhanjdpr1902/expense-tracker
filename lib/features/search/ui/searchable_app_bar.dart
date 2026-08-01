import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import 'search_expand.dart';

/// An [AppBar] whose search field grows out of the search icon, using the same
/// [ExpandReveal] as the full-screen search route — only at bar scale, so both
/// entry points read as one gesture.
///
/// The field must be able to cover the filter/add actions, so the title *and*
/// the actions live in the `title` slot: that makes the whole bar row one
/// widget this class owns.
class SearchableAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SearchableAppBar({
    super.key,
    required this.title,
    required this.animation,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onQueryChanged,
    required this.onSubmitted,
    required this.onOpen,
    required this.onClose,
    required this.onClear,
    required this.actions,
    this.bottom,
  });

  final String title;

  /// 0 = collapsed, 1 = fully expanded. Taken as an [Animation] rather than a
  /// double so only this bar rebuilds per frame — a page-level listener would
  /// rebuild the whole list 25 times per open.
  final Animation<double> animation;

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The committed query — drives the collapsed "active search" chip.
  final String? query;

  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onClear;

  /// The page's existing actions (filter, add) — unchanged.
  final List<Widget> actions;

  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final iconKey = GlobalObjectKey('$title-search-icon');
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.expandReverse,
    );

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      bottom: bottom,
      title: AnimatedBuilder(
        animation: curved,
        builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final progress = curved.value;
          final barHeight = kToolbarHeight - 12;
          final bar = Offset.zero & Size(constraints.maxWidth, barHeight);

          // Icon rect in this Stack's space, with a fallback for the frame
          // before the resting row has laid out (e.g. arriving deep-linked
          // with the field already open).
          Rect origin;
          final global = globalRectOf(iconKey);
          final box = context.findRenderObject() as RenderBox?;
          if (global != null && box != null && box.hasSize) {
            origin = box.globalToLocal(global.topLeft) & global.size;
          } else {
            origin = Rect.fromLTWH(bar.right - 48, 0, 40, 40);
          }

          return SizedBox(
            height: barHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Resting row — gone by the time the field is half open.
                Opacity(
                  opacity: (1 - progress * 2).clamp(0.0, 1.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).appBarTheme.titleTextStyle,
                        ),
                      ),
                      if (query != null)
                        _ActiveSearchChip(
                          key: iconKey,
                          query: query!,
                          onTap: onOpen,
                          onClear: onClear,
                        )
                      else
                        IconButton(
                          key: iconKey,
                          tooltip: 'Search',
                          icon: const Icon(Icons.search_rounded),
                          onPressed: onOpen,
                        ),
                      ...actions,
                    ],
                  ),
                ),
                if (progress > 0)
                  ExpandReveal(
                    progress: progress,
                    origin: origin,
                    target: bar,
                    beginRadius: 18,
                    // A field, not a circle.
                    endRadius: AppRadii.chip,
                    surfaceColor: context.cardSurface,
                    borderColor: context.hairline,
                    child: _FieldRow(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onQueryChanged,
                      onSubmitted: onSubmitted,
                      onClose: onClose,
                    ),
                  ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: AppSpacing.md),
        Icon(Icons.search_rounded, size: 18, color: context.inkMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: AppTextStyles.body.copyWith(color: context.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintStyle: AppTextStyles.body.copyWith(color: context.inkSubtle),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close search',
          iconSize: 20,
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// Collapsed state of an active scoped query.
///
/// Deliberately *not* the filter screen's green dot: reusing that would make
/// "Reset filters" leave the dot lit, which reads as a bug. A labelled chip is
/// self-documenting and clears in one tap.
class _ActiveSearchChip extends StatelessWidget {
  const _ActiveSearchChip({
    super.key,
    required this.query,
    required this.onTap,
    required this.onClear,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search: $query',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(maxWidth: 132),
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 14, color: context.ink),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                      color: context.ink, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Clear search',
                iconSize: 14,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
