import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import 'highlight.dart';

/// A result row for sections that have no existing tile (projects,
/// categories).
///
/// Mirrors `RecordTile`'s anatomy exactly — 44×44 bordered icon box at
/// [AppRadii.chip], 14px gap, one-line title, muted subline, trailing figure —
/// so all five search sections read as a single continuous list rather than a
/// stack of different components.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.highlight,
    this.tint = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  /// Query to emphasise inside [title] / [subtitle].
  final String? highlight;

  /// Soft green icon box, matching how income and loan rows are tinted.
  final bool tint;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        AppTextStyles.body.copyWith(color: context.ink, fontWeight: FontWeight.w600);
    final subStyle = AppTextStyles.caption.copyWith(color: context.inkMuted);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.inner),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: tint ? context.palette.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(color: context.hairline),
              ),
              child: Icon(icon, size: 20, color: context.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    highlightSpan(title, highlight,
                        base: titleStyle,
                        match: highlightStyle(context, titleStyle)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      highlightSpan(subtitle!, highlight,
                          base: subStyle,
                          match: highlightStyle(context, subStyle)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                trailing!,
                style: AppTextStyles.body
                    .copyWith(color: context.ink, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
