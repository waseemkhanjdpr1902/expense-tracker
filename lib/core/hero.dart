import 'package:flutter/material.dart';

/// Names the list a tile lives in, so the *same* record rendered in two places
/// gets two distinct Hero tags.
///
/// This is not theoretical. `RecordTile` renders in Home, Records and search
/// results, and Home and Records are **adjacent children of one `PageView`
/// inside a single route** — during a swipe both are laid out at once. A naked
/// `Hero(tag: record.id)` is then a hard assertion ("multiple heroes share the
/// same tag within a subtree") reachable by swipe-then-tap.
class HeroScope extends InheritedWidget {
  const HeroScope({super.key, required this.name, required super.child});

  final String name;

  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeroScope>()?.name;

  @override
  bool updateShouldNotify(HeroScope oldWidget) => oldWidget.name != name;
}

/// Hero tag builders.
///
/// A null scope yields a null tag, which [MaybeHero] renders without a Hero at
/// all. Forgetting a [HeroScope] therefore costs an animation, never a crash —
/// which is the right failure mode for a purely decorative flight.
abstract final class HeroTags {
  static String? record(String? scope, String id) =>
      scope == null ? null : '$scope/record/$id';

  static String? project(String? scope, String id) =>
      scope == null ? null : '$scope/project/$id';
}

/// Wraps [child] in a [Hero] only when [tag] is non-null.
class MaybeHero extends StatelessWidget {
  const MaybeHero({super.key, required this.tag, required this.child});

  final Object? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => tag == null
      ? child
      : Hero(
          tag: tag!,
          // The default shuttle rebuilds the subtree into the overlay, which
          // loses Material ancestry; a plain box keeps the badge painting
          // identically mid-flight.
          flightShuttleBuilder: (_, _, _, _, _) => child,
          child: child,
        );
}
