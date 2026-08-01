---
name: flutter-motion
description: How to build animations and transitions in this Flutter app so they feel smooth and cost nothing — implicit vs explicit choice, AnimationController lifecycle, the child-parameter rule, custom page routes, staggering, and the jank traps specific to animated UI.
when_to_use: Any task involving animation, transition, motion, gesture-driven movement, expanding/collapsing UI, page routes, Hero, fade, slide, scale, stagger, AnimationController, Tween, or "make it smoother".
---

# Flutter motion — house rules

## Pick the cheapest tier that works

1. **Existing primitive** — `FadeIn`, `XSwitcher`, `AnimatedMoney`, `PressScale`
   (`lib/core/motion.dart`). Always check here first.
2. **Implicit** — `AnimatedContainer`, `AnimatedOpacity`, `AnimatedScale`,
   `AnimatedAlign`, `TweenAnimationBuilder`. No controller, no lifecycle. Default
   choice for a one-shot state change.
3. **Explicit** — `AnimationController` only when you need to drive, reverse,
   interrupt, or share progress across widgets.

Never reach for tier 3 to do tier 2's job.

## Tokens

`AppMotion.fast` 160ms · `med` 220ms · `slow` 320ms · `enter` = `easeOutCubic` ·
`exit` = `easeIn`. Add a token to `motion.dart` rather than inlining a new
duration; one-off values make the app feel assembled from parts.

Rough guidance: micro-feedback ≤160ms, content swap ~220ms, surface/route
~320-420ms. Longer than ~500ms reads as slow, not smooth.

## AnimationController lifecycle

- `SingleTickerProviderStateMixin` for one controller; `TickerProviderStateMixin`
  for two or more. Adding a second controller to a class that has the single-
  ticker mixin throws at runtime.
- Always `dispose()` the controller, and remove any listener you added.
- `vsync` is what stops offscreen animations from burning frames — never fake it.

## The child-parameter rule (most-missed optimisation)

`AnimatedBuilder` / `TweenAnimationBuilder` / `ValueListenableBuilder` all take a
`child`. Anything in the subtree that does **not** depend on the animation value
goes there and is built **once**; the builder receives it back as a parameter.

```dart
AnimatedBuilder(
  animation: _ctrl,
  child: const ExpensiveStaticSubtree(),   // built once
  builder: (context, child) => Transform.scale(
    scale: _ctrl.value,
    child: child,                           // reused every frame
  ),
)
```

Putting that subtree inside `builder` rebuilds it on every tick — 60 rebuilds a
second of widgets that never change.

## Animate the cheap properties

Prefer `Transform`, `Opacity` via `FadeTransition`/`AnimatedOpacity`, and
alignment. Avoid animating anything that triggers a **layout** pass every frame
(width/height on a widget whose parent must re-measure, `Padding`, intrinsic
sizing) when a `Transform` would do.

- Clipping during an animation is expensive — pre-clip, or clip a fixed shape and
  animate the contents inside it.
- Prefer `FadeTransition` over rebuilding with `Opacity` each frame.
- Avoid `saveLayer()`: `Opacity` on a large subtree, `ShaderMask`, `ColorFilter`
  and `BackdropFilter` are the usual culprits. Drawing a semi-transparent colour
  directly is free by comparison.
- `RepaintBoundary` around a small, continuously animating widget stops it
  repainting the rest of the screen. Wrap the animated thing, not the page.

## Reveal/expand transitions

To grow a surface from a source rect: **clip, never scale**. Lay the child out at
its final size and open a window over it (`ClipRRect` + `OverflowBox` +
`Transform.translate`). Scaling the child makes text visibly squash and re-flow,
which reads as cheap; clipping makes the content look like it was always there.

Capture a source rect at **tap** time, not build time, if the source can scroll:

```dart
final box = key.currentContext?.findRenderObject() as RenderBox?;
final rect = box!.localToGlobal(Offset.zero) & box.size;
```

## Custom page routes

`PageRouteBuilder` with `opaque: false` when the previous screen must stay
visible behind. Paint your own scrim in-tree (driven by the same animation value)
rather than using `barrierColor`, so it animates in lockstep. Set
`transitionDuration` and `reverseTransitionDuration` separately — exits should be
faster than entrances.

The app theme overrides page transitions for Android only
(`FadeForwardsPageTransitionsBuilder`, `theme.dart:216`); a custom route bypasses
it.

## Keyboard + transitions

If a route animates while the keyboard appears, set
`resizeToAvoidBottomInset: false` on that Scaffold and pad manually with
`MediaQuery.viewInsetsOf(context).bottom`. Otherwise the Scaffold resizes
mid-flight, the target geometry moves, and the animation stutters.

Request focus on `AnimationStatus.completed` rather than using
`autofocus: true`, so the keyboard follows the surface instead of racing it. On
close, unfocus and wait ~80ms before popping.

## Staggering

Stagger groups, not rows — five delays read as considered, twenty read as a slot
machine. ~30-40ms between items.

`FadeIn` is a `TweenAnimationBuilder`: it animates on the **first build of a given
element**. To make it replay when content changes, give it a `ValueKey` that
includes what changed. A key that changes every rebuild replays it every frame.

## Verifying

Run with slow animations (DevTools → Slow animations, or `timeDilation = 5.0`)
and watch for: content squashing, geometry jumping at the start or end, the
keyboard fighting the surface, and anything that fails to reverse to its exact
origin. Profile in **profile mode on a physical device** — debug-mode frame times
are meaningless.
