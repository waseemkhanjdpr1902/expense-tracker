---
name: flutter-accessibility
description: Accessibility requirements for this Flutter app — 48dp tap targets, Semantics labels for icon-only controls, text scaling, colour contrast and non-colour affordances, plus the flutter_test guideline matchers that assert them automatically.
when_to_use: Any task adding a tappable control, icon button, chip, custom gesture, colour-coded status, form field, or dialog — and any accessibility, a11y, screen reader, contrast, or text-scaling question.
---

# Flutter accessibility — house rules

## Tap targets: 48×48dp minimum

Applies to every tappable thing — icon buttons, chips, close ×, list-row
affordances, custom `GestureDetector`s. `IconButton` gives 48dp by default;
a bare `GestureDetector` around a 20px icon does not.

Keep the *visual* smaller if the design needs it, and expand only the target:

```dart
SizedBox(
  height: 48, width: 48,                       // target
  child: Center(child: SizedBox(
    height: 36, width: 36, child: visual)),    // what you see
)
```

If a design deliberately ships a smaller target (this app's 40dp header chips),
say so explicitly rather than letting it pass silently.

## Icon-only controls need a label

An icon conveys nothing to a screen reader. Every icon-only control gets either:

```dart
IconButton(tooltip: 'Filter', ...)              // tooltip doubles as the label
Semantics(button: true, label: 'Search', child: ...)   // for custom gestures
```

Label the **action**, not the glyph: "Clear search", not "X icon". Decorative
imagery gets `ExcludeSemantics` so it isn't announced.

## Never encode meaning in colour alone

Green/red for income/expense is fine only because a sign (`+`/`−`) and an icon
carry the same information. Any new status must be legible in greyscale and to a
colour-blind user: pair colour with a label, sign, icon or shape.

Contrast: **4.5:1** minimum for text and controls against their background.
`context.inkSubtle` (38% ink) is at the edge — use it for decoration, never for
information a user must read.

## Text scaling

Users run up to 200%+. Never set a fixed `height` on a widget whose size is
driven by text; let it grow. Test at large scale — the common failures are
overflow stripes on chips, clipped single-line buttons, and cards with a hard
`SizedBox(height:)` around text.

`maxLines` + `ellipsis` is the correct response to long text, not a fixed height.

## Announce dynamic changes

When something happens without a visual transition the user is looking at (a
background save, a filter applied, an item deleted), the SnackBar already speaks.
For live-region-style updates use `Semantics(liveRegion: true, ...)`.

## Assert it in tests

`flutter_test` ships matchers — these turn a11y from opinion into a failing test:

```dart
testWidgets('meets a11y guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const ProviderScope(child: XpenseApp()));

  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  handle.dispose();
});
```

Add these when touching a screen's controls.

## Manual check

Enable TalkBack on the emulator/device and traverse the screen: every control
should be reachable, announce a meaningful label, and expose its state. Then
raise the system font size to maximum and re-check for overflow.
