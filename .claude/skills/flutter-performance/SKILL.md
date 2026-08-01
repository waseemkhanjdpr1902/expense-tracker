---
name: flutter-performance
description: Rendering and rebuild performance rules for this Flutter app — the 16ms frame budget, const and rebuild scoping, lazy lists, expensive paint operations, intrinsic layout passes, and how to actually profile rather than guess.
when_to_use: Any task involving jank, dropped frames, slow scrolling, long lists, a screen that feels heavy, profiling, or a review of code that rebuilds or paints frequently.
---

# Flutter performance — house rules

## Budget

16ms per frame at 60Hz (≈8ms build + 8ms raster), 8ms at 120Hz. Miss it and the
user sees a stutter.

**Measure in profile mode on a physical device.** Debug builds are 10-50× slower
and their timings mean nothing. `flutter run --profile`, then DevTools →
Performance.

## Scope rebuilds

- `setState()` rebuilds the widget **and every descendant**. Push it as far down
  the tree as possible: extract the changing part into its own small
  `StatefulWidget` rather than calling `setState` at the top of a screen.
- `const` constructors let Flutter short-circuit the rebuild entirely. Use `const`
  everywhere it compiles — `flutter_lints` (already enabled) flags the misses.
- Never override `operator ==` on a `Widget`. It degrades to O(N²) tree diffing.
- Watch the narrowest thing: `ref.watch(p.select((v) => v.field))` rather than the
  whole object when only one field is used.

## Lists

- Always `ListView.builder` / `SliverList.builder` for anything that can grow.
  A `Column` or a `ListView(children: [...])` builds every child immediately,
  visible or not.
- Give list items stable `ValueKey`s so element reuse and `Dismissible` work.
- One stream per row is an N+1 subscription. If the page already holds an
  aggregate for the whole list, pass the value down instead of opening a
  per-row provider.
- Nested scrollables and unbounded heights force expensive layout — give lists
  bounded constraints.

## Expensive paint operations

Ranked worst first:

1. **`saveLayer()`** — allocates an offscreen buffer and switches render target.
   Triggered by `Opacity` over a subtree, `ShaderMask`, `ColorFilter`,
   `BackdropFilter`, and `Text` with an overflow shader. Check
   `checkerboardOffscreenLayers` in DevTools.
2. **Clipping** — costly even without `saveLayer`. Prefer a `BoxDecoration`
   `borderRadius` over wrapping in a `ClipRRect`. `Clip.none` is the default;
   only opt in when you need it.
3. **`Opacity`** — draw a semi-transparent colour directly instead where you can;
   use `FadeTransition`/`AnimatedOpacity` for animated fades.
4. **Large blurs** — `BackdropFilter` is per-frame GPU work. The frosted nav bar
   already costs one; don't add more.

## Intrinsic layout passes

`IntrinsicHeight`, `IntrinsicWidth` and some table/grid layouts measure **every**
child (not just the visible ones), then lay out again. On a long list this is a
frame killer. Use fixed extents (`itemExtent`, `prototypeItem`) or a fixed cell
size instead. DevTools → "Track layouts" surfaces `$runtimeType intrinsics`
events.

## Repaint isolation

`RepaintBoundary` around a small, frequently repainting subtree (an animation, a
`CustomPaint`, a live-updating figure) keeps its repaints off the rest of the
screen. Wrap the animated widget — wrapping the whole page achieves nothing and
costs a layer.

## Other

- `StringBuffer`, not `+`, when concatenating in a loop.
- Decode images at display size; don't ship a 4K asset into a 44px avatar.
- Keep `build()` free of I/O, sorting large lists, date parsing and regex
  compilation — hoist those to state or a provider.
- This app folds all records in Dart (`watchStats()`), which is fine at
  personal-ledger scale. If row counts ever reach thousands, move the folding
  into SQL aggregates rather than optimising the widget layer.

## Diagnosing, in order

1. Reproduce in profile mode on device.
2. DevTools → Performance → find the janky frame; is it **UI** (Dart/build) or
   **Raster** (GPU/paint)?
3. UI-bound → "Show widget rebuild information", then scope the rebuild.
4. Raster-bound → `checkerboardOffscreenLayers`, look for saveLayer/blur/clip.
5. Fix one thing, re-measure. Never "optimise" without a before number.
