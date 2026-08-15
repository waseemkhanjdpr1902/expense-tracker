import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';

/// One chrome for every bottom sheet.
///
/// The app had eight sheets in two incompatible styles — five with a
/// transparent background and hand-rolled chrome, three using the theme
/// default — and none with a drag handle.
abstract final class AppSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool scrollable = true,
    bool transparent = false,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: scrollable,
        useSafeArea: true,
        showDragHandle: !transparent,
        backgroundColor:
            transparent ? Colors.transparent : context.palette.bgCard,
        elevation: 0,
        clipBehavior: transparent ? Clip.none : Clip.antiAlias,
        shape: transparent
            ? null
            : const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppRadii.hero)),
              ),
        // Material's default is faster and stiffer than the rest of the app.
        sheetAnimationStyle: AnimationStyle(
          duration: AppMotion.slow,
          curve: AppMotion.enter,
          reverseDuration: AppMotion.med,
          reverseCurve: AppMotion.exit,
        ),
        builder: builder,
      );
}

/// Glass chrome for a sheet's own content.
///
/// Replaces the container each `transparent: true` sheet was hand-rolling — an
/// opaque fill at radius 24, while the theme's sheet radius is 28, five times
/// over. Sheets are one of the surfaces Apple names as adopting the material,
/// and unlike the nav bar they sit over *frozen* content, so the blur is
/// sampled once instead of every frame of a scroll.
///
/// The keyboard inset is handled here too, because every one of those five
/// copies also had to remember it.
/// Takes [padding] and [child] in the same shape as the `Container` it
/// replaces, so adopting it is a one-line swap at each call site rather than a
/// re-nesting that could silently drop a `SafeArea`.
class GlassSheet extends ConsumerWidget {
  const GlassSheet({super.key, required this.padding, required this.child});

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noGlass = glassDisabled(context);

    return GlassSurface(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadii.hero)),
      prominence: GlassProminence.sheet,
      disabled: noGlass,
      // No rim: a sheet's left, right and bottom edges run off-screen, so a
      // full ring would draw a lit edge along seams that aren't there.
      rim: false,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The 36×4 grab handle every sheet was drawing by hand.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: context.hairline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
