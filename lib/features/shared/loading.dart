import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';

/// Shows nothing for the first [delay], then reveals [child].
///
/// These are local SQLite reads that return in single-digit milliseconds. A
/// spinner shown for 8ms is not information — it is a flash. Suppressing it
/// below the perception threshold makes the app feel *faster*, not slower,
/// because nothing visibly churns.
class DelayedVisible extends StatelessWidget {
  const DelayedVisible({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 140),
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: Future<void>.delayed(delay),
        builder: (context, snapshot) =>
            snapshot.connectionState == ConnectionState.done
                ? FadeIn(duration: AppMotion.fast, child: child)
                : const SizedBox.shrink(),
      );
}

/// A single grey bar, pulsing.
///
/// Skeletons say "here is the shape of what's coming"; a spinner only says
/// "wait". Colours come from the palette, so this composes with the dark ramp
/// rather than hard-coding a grey.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadii.chip,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.palette.separator;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: base.a * (0.45 + 0.55 * _pulse.value)),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder rows shaped like `RecordTile` — 44 badge, title bar, subline.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  const SkeletonBox(width: 44, height: 44),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                          width: 150 - (i % 3) * 24, height: 13, radius: 4),
                      const SizedBox(height: 7),
                      const SkeletonBox(width: 92, height: 10, radius: 4),
                    ],
                  ),
                  const Spacer(),
                  const SkeletonBox(width: 64, height: 13, radius: 4),
                ],
              ),
            ),
        ],
      );
}
