---
name: flutter-ui
description: Design-system rules for building or changing any UI in this Flutter app — tokens, Material 3 theming, light/dark parity, spacing, typography, money formatting, and the widget vocabulary to reuse. Use whenever writing or editing a widget, screen, card, chip, sheet, dialog, list row, empty state, or anything visual.
when_to_use: Any task that adds or edits a Flutter widget, screen, layout, colour, padding, radius, font, card, button, chip, bottom sheet, dialog, list row, badge, empty state, or theme.
---

# Flutter UI — house rules

## Tokens are mandatory. Never hardcode.

| Need | Use | Never |
| --- | --- | --- |
| Spacing | `AppSpacing.xs/sm/md/lg/xl/xxl/xxxl` (4/8/12/16/20/24/32) | raw `EdgeInsets.all(13)` |
| Radius | `AppRadii.hero/card/inner/chip/pill` (28/20/14/12/100) | raw `BorderRadius.circular(17)` |
| Type | `AppTextStyles.display/headline/title/body/caption/overline` | raw `TextStyle(fontSize: …)` |
| Motion | `AppMotion.fast/med/slow`, `AppMotion.enter/exit` | raw `Duration(milliseconds: 300)` |
| Accent | `AppColors.green`, `AppColors.danger`, `AppColors.greenSoft` | raw hex |

All from `lib/core/theme.dart` + `lib/core/motion.dart`.

## Theme-reactive colour comes from `BuildContext`

```dart
context.ink          // primary text
context.inkMuted     // secondary text
context.inkSubtle    // tertiary / hints
context.hairline     // 1px borders + dividers
context.surface      // page background
context.cardSurface  // cards — lifts above the page in dark mode
context.softShadow   // restrained elevation
```

Use these, not ad-hoc `Theme.of(context).colorScheme.*`. A literal `Colors.white`
/ `Colors.black` / `Colors.grey[300]` in a widget is a bug — it will invert
wrongly in the other theme.

**Every visual change must be checked in light AND dark.** This is the single
most common defect class in this repo's history.

## Money

- Always `int` minor units end-to-end. Format only at the render edge.
- `formatMoney(minor, currency)` / `formatMoneySigned(...)` from `core/currency.dart`.
- Animating a figure → `AnimatedMoney(minor:, currency:)`, never a raw `Text`.
- Never negate by string. Pass `signed: true, negative: …` or negate the int first
  so `formatMoney` never receives a negative.
- Every `AppTextStyles` entry already carries `FontFeature.tabularFigures()`.
  Keep it on any new style, or digits jitter while animating and columns misalign.

## Reuse before you build

Check these first — they exist and are already styled:

| Need | Widget |
| --- | --- |
| Record row | `RecordTile` (`features/records/widgets/record_tile.dart`) — handles all 4 record types |
| Section label | `SectionHeader` — takes an optional `trailing` |
| Totals strip | `SummaryBoard` + `BoardStat` (`features/shared/totals_strip.dart`) |
| Entrance | `FadeIn({delay, offset})` |
| Swap content | `XSwitcher` — children need a `ValueKey` |
| Tap feedback | `PressScale` |

Filter chips (`_Chip`), add-chips and date tiles are deliberately duplicated per
page. Match the local copy in the file you're editing; do not extract them
mid-task.

## Structure

- One `Scaffold` per tab page, each with its own `RefreshIndicator`.
- Tab pages that hold filter state use `AutomaticKeepAliveClientMixin` and must
  call `super.build(context)`.
- Bottom padding on scrollables is `120` — the floating nav bar overlays content
  (`extendBody: true`).
- `AppBar`: flat, `centerTitle: false`, no scroll elevation. Actions are icons.
- Theme sets `splashFactory: NoSplash.splashFactory` — InkWell gives highlight,
  not ripple. Don't reintroduce ripples locally.

## Text safety

Every user-supplied string (`description`, `counterparty`, project `name`) can be
long. Always set `maxLines` + `overflow: TextOverflow.ellipsis`, or constrain the
width. Titles are 1 line; sublines are 1 line.

## States

Every async surface needs three: loading, empty, error — and the empty state must
distinguish "nothing exists yet" (offer the action) from "nothing matches the
current filter" (offer to adjust it). Wrap in `XSwitcher` with distinct
`ValueKey`s so they cross-fade instead of popping.

## Dialogs and sheets

Never hold a `TextEditingController` in a dialog or bottom sheet. Use a plain
`TextField` with `onChanged` writing to a local `String` and `onSubmitted`
popping the value. A controller disposed when the dialog future completes still
gets rendered for ~200ms during the close animation and throws
`_dependents.isEmpty is not true`. See the comment at `record_form_page.dart:260`.
Controllers belong only in long-lived page `State` (`initState`/`dispose`).
