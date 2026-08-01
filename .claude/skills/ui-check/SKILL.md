---
name: ui-check
description: Run the pre-ship checklist over UI work in this Flutter app — analyze, tokens, light/dark parity, tap targets, overflow, states, motion and rebuild scoping — then verify it on the emulator with screenshots.
when_to_use: Invoke with /ui-check after finishing a screen, widget or visual change, or when asked to review or verify UI work before shipping.
argument-hint: [screen or feature to check]
---

# UI check

Work through this against the diff (`git diff`) for $1. Report findings as a
short list — file:line, what's wrong, the fix. Say plainly if nothing is wrong.

## 1. Static

```bash
flutter analyze
flutter test
```
Both must be clean of *new* issues. Pre-existing ones are noted, not fixed
silently.

## 2. Tokens

Grep the diff for hardcoded values that should be tokens:

```bash
git diff -U0 -- '*.dart' | grep -nE '^\+' | \
  grep -E "Colors\.(white|black|grey|red|green)|fontSize: [0-9]|circular\([0-9]|EdgeInsets\.[a-z]+\([0-9]|Duration\(milliseconds"
```

Each hit is either a token (`AppColors`/`AppSpacing`/`AppRadii`/`AppTextStyles`/
`AppMotion`) or a theme-reactive `context.*` colour, or it needs a justification.

## 3. Light + dark

Run the app, screenshot the changed screen in **both** themes (Settings → Theme).
Check: text legible, card surfaces lift off the page, hairlines visible, accent
colours not vibrating against the background, no white-on-white or black-on-black.

## 4. Text and layout

- Every user-supplied string has `maxLines` + `overflow`.
- No fixed `height` wrapping text.
- Raise system font size to max — no overflow stripes, no clipping.
- Check the narrowest supported width.

## 5. Controls

- Tap targets ≥48dp (or a deliberate, stated exception).
- Icon-only controls have `tooltip:` or `Semantics(label:)`.
- Status is never conveyed by colour alone.

## 6. States

Loading, empty and error all render. The empty state distinguishes "nothing yet"
from "nothing matches the filter". `XSwitcher` children carry distinct
`ValueKey`s.

## 7. Motion

- Durations/curves come from `AppMotion`.
- `AnimatedBuilder`/`TweenAnimationBuilder` pass static subtrees via `child:`.
- Controllers disposed; ticker mixin matches controller count.
- Run once with slow animations — nothing squashes, jumps, or fails to reverse.

## 8. Rebuilds

- `const` wherever it compiles.
- `setState` scoped to the smallest subtree.
- `ListView.builder` for anything growable; stable keys on items.
- No per-row provider when the page already holds the aggregate.
- New family key class fields appear in **both** `==` and `hashCode`.

## 9. On device

```bash
flutter run -d emulator-5554
```
Settings → Developer → Load demo data, then exercise the actual flow — including
the interaction that was hardest to get right. Screenshot the result.
