import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';

/// The on-screen rect of a laid-out widget, or null if it hasn't been laid out.
///
/// Read this at **tap** time, not build time — the Home header lives in a
/// scrolling list, so a rect captured during build goes stale.
Rect? globalRectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Grows a rounded surface from [origin] to [target] as [progress] goes 0 → 1.
///
/// The child is **always laid out at the target size and clipped** — never
/// scaled. That is what makes the motion read as a window opening over content
/// that was already there, rather than a thumbnail being stretched: nothing
/// inside squashes, and text never re-flows mid-flight.
///
/// Shared by the full-screen search route and the in-AppBar scoped field so
/// both are literally the same gesture at different scales. Must be placed in a
/// [Stack]; [origin] and [target] are in that Stack's coordinate space.
class ExpandReveal extends StatelessWidget {
  const ExpandReveal({
    super.key,
    required this.progress,
    required this.origin,
    required this.target,
    required this.child,
    this.beginRadius = 18,
    this.endRadius = 0,
    this.borderColor,
    this.surfaceColor,
  });

  final double progress;
  final Rect origin;
  final Rect target;
  final double beginRadius;
  final double endRadius;
  final Color? borderColor;
  final Color? surfaceColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rect = Rect.lerp(origin, target, progress)!;
    final radius = lerpDouble(beginRadius, endRadius, progress)!;
    final border = borderColor;

    return Positioned.fromRect(
      // Stack-local coordinates.
      rect: rect.shift(-target.topLeft),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor ?? context.surface,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          // The hairline fades out as the surface takes over the screen.
          border: border == null
              ? null
              : Border.all(
                  color: border.withValues(alpha: border.a * (1 - progress)),
                ),
        ),
        clipBehavior: Clip.antiAlias,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: target.width,
          maxWidth: target.width,
          minHeight: target.height,
          maxHeight: target.height,
          // Pin the full-size child to the target origin so its contents stay
          // still while the window over them opens.
          child: Transform.translate(
            offset: target.topLeft - rect.topLeft,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Full-screen route that grows out of [origin] and shrinks back into it.
///
/// The app's first custom route: it overrides [buildTransitions], bypassing the
/// theme's `FadeForwardsPageTransitionsBuilder` for this one route.
class SearchExpandRoute<T> extends PageRouteBuilder<T> {
  SearchExpandRoute({
    required this.origin,
    required WidgetBuilder builder,
  }) : super(
          // The shell stays visible (and dimmed) behind the growing surface.
          opaque: false,
          // No barrierColor — the scrim is painted in-tree below so it animates
          // off the same value as the geometry.
          barrierDismissible: false,
          transitionDuration: AppMotion.expand,
          reverseTransitionDuration: AppMotion.slow,
          pageBuilder: (context, _, _) => builder(context),
        );

  final Rect origin;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final screenSize = MediaQuery.sizeOf(context);
    final screen = Offset.zero & screenSize;

    // Guard a stale origin (e.g. the screen resized while the route was open).
    final safeOrigin = screen.overlaps(origin)
        ? origin
        : Rect.fromCircle(
            center: Offset(screenSize.width - 44, 44), radius: 20);

    final t = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.expandReverse,
    );
    // Content lands after the shape is mostly open, and leaves first.
    final contentFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0.55, 1, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: t,
      // The page is built once and handed back as `page` — never rebuilt per
      // frame.
      child: child,
      builder: (context, page) {
        final v = t.value;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.38 * v),
                ),
              ),
            ),
            ExpandReveal(
              progress: v,
              origin: safeOrigin,
              target: screen,
              // A circle at rest, matching the round icon it grows from.
              beginRadius: safeOrigin.shortestSide / 2,
              endRadius: 0,
              borderColor: context.hairline,
              child: FadeTransition(opacity: contentFade, child: page!),
            ),
          ],
        );
      },
    );
  }
}
