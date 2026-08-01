import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/haptics.dart';
import '../../core/icons.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';

/// The app's one empty state.
///
/// Replaces seven hand-rolled variants with glyph sizes of 40, 48 and 56, two
/// illustration heights, and a call to action on only one of them. An empty
/// screen is the moment a user most needs telling what to do next, so every
/// instance can now carry an action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.boxed = false,
    this.compact = false,
  }) : assert(icon != null || illustration != null,
            'an empty state needs something to look at');

  /// One of these two. [illustration] is an SVG asset path.
  final IconData? icon;
  final String? illustration;

  final String title;
  final String? message;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Card treatment, for an empty section sitting inside a populated page.
  final bool boxed;

  /// Inline (a section of a list) rather than a full page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final glyph = illustration != null
        ? SvgPicture.asset(
            illustration!,
            height: compact ? 96 : 128,
            theme: SvgTheme(currentColor: p.label),
          )
        // A glyph inside a soft disc reads as a considered empty state; a bare
        // grey icon reads as a missing asset.
        : Container(
            width: compact ? 72 : 88,
            height: compact ? 72 : 88,
            decoration: BoxDecoration(color: p.bgCard, shape: BoxShape.circle),
            child: Icon(icon,
                size: compact ? 32 : AppIconSize.empty,
                color: p.labelSecondary),
          );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
        Text(title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title.copyWith(color: p.label)),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: p.labelSecondary)),
        ],
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              minimumSize: const Size(0, 46),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            ),
            onPressed: () {
              AppHaptics.light();
              onAction!();
            },
            child: Text(actionLabel!),
          ),
        ],
      ],
    );

    final padded = Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.xxl : AppSpacing.xxxl),
      child: content,
    );

    return FadeIn(
      child: boxed
          ? Container(
              decoration: BoxDecoration(
                color: p.bgCard,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: p.separator),
              ),
              child: padded,
            )
          : Center(child: padded),
    );
  }

  /// Full-height variant that still scrolls, so `RefreshIndicator` keeps
  /// working — replaces the hand-rolled `ListView + SizedBox(height: 0.65h)`
  /// pattern that several pages had grown independently.
  Widget scrollable(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: this,
          ),
        ],
      );
}
