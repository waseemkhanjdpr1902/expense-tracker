import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';

/// The app's one icon anchor.
///
/// Replaces the 44×44 recipe that was hand-rolled in five places with three
/// different sizes and two different radii (`record_tile.dart`,
/// `add_record_sheet.dart`, `loans_page.dart`, `home_page.dart`,
/// `categories_page.dart`).
///
/// It consumes palette tokens and defines no colour of its own, and it is the
/// subject of the list→detail Hero flight — which is why source and
/// destination must use the same [size].
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.size = 44,
    this.iconSize = AppIconSize.md,
    this.tinted = false,
    this.foreground,
    this.radius,
  });

  final IconData icon;

  /// Container size. Keep source and destination equal across a Hero flight —
  /// the glyph does not scale with the box, so a growing badge overflows.
  final double size;

  final double iconSize;

  /// Soft accent wash instead of a plain bordered box — used for income and
  /// loan rows, matching the existing visual language.
  final bool tinted;

  final Color? foreground;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = foreground ?? (tinted ? p.accent : p.label);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tinted ? p.accentSoft : null,
          borderRadius:
              BorderRadius.circular(radius ?? (size <= 44 ? AppRadii.chip : AppRadii.inner)),
          border: tinted ? null : Border.all(color: p.separator),
        ),
        child: Center(child: Icon(icon, size: iconSize, color: fg)),
      ),
    );
  }
}
