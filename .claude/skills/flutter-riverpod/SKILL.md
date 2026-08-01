---
name: flutter-riverpod
description: Riverpod 2 rules for this app — hand-written providers only (no codegen), family key classes that must implement == and hashCode, when autoDispose is required, watch vs read vs listen, and how drift streams feed the UI.
when_to_use: Any task adding or editing a provider, a StreamProvider.family, a Notifier, a query key class, or wiring database data into a widget — and any question about state management, rebuilds not happening, or stale cached data.
---

# Riverpod in this app — house rules

## Hand-written providers only

`riverpod_annotation` / `riverpod_generator` are in `pubspec.yaml` but **no
`@riverpod` annotation exists anywhere**. The only generated file is
`database.g.dart` (drift). Do not introduce provider codegen for one file — it
splits the codebase into two idioms.

## Family keys: `==` and `hashCode` are load-bearing

Family arguments are value classes (`RecordsQuery`, `LoansQuery`,
`RecordsTotalsQuery`, `ChartDateRange`) with hand-written equality.

**Adding a field without updating both operators is a silent bug**: the new key
compares equal to the old one, Riverpod serves the cached provider, and the UI
appears to ignore the change entirely. No error, no warning.

```dart
class SomeQuery {
  final String? newField;                       // 1. add the field
  @override
  bool operator ==(Object o) =>
      o is SomeQuery && o.newField == newField && …;   // 2. AND here
  @override
  int get hashCode => Object.hash(newField, …);        // 3. AND here
}
```

Sets need `containsAll` + `Object.hashAllUnordered`, not `==` on the Set.

## autoDispose

Required whenever the family key space is **unbounded** — anything keyed by free
text (a search query) or by an open-ended value. Without it, every key ever used
retains a live stream subscription and its last result for the process lifetime.

Not needed for closed key spaces (an enum, a fixed filter object) — and this
codebase deliberately does not use it elsewhere. Don't do a blanket conversion.

**The cost:** changing an autoDispose family key disposes the old provider, so
the new one starts in `AsyncLoading`. Anything showing a spinner on that state
will flash on every keystroke. Hold the last good value in the widget's State and
dim it instead of swapping in a spinner.

## watch / read / listen

- `ref.watch` — in `build`, to rebuild on change. Never in a callback.
- `ref.read` — in callbacks and event handlers only. Never in `build`.
- `ref.listen` — for side effects (snackbars, navigation, one-shot triggers).
  Never call `setState` from it without a mounted guard.
- `ref.watch(p.select((v) => v.field))` when only one field matters.
- Never `ref.watch` an autoDispose provider from a non-autoDispose one — it can
  never dispose.

## Drift streams

DB reads are `StreamProvider` over `.watch()` queries, so any write re-emits and
the UI updates with no manual invalidation. Prefer adding an optional parameter
to an existing `watchX()` (every filter there is an AND-composed
`if (x != null)`) over writing a parallel method.

`ref.invalidate(provider)` is for pull-to-refresh and post-restore rebuilds, not
for routine updates — the stream already handles those.

## AsyncValue

- `.when(loading:, error:, data:)` for full handling; `.valueOrNull ?? fallback`
  for the "just show something" case.
- `valueOrNull` being null is ambiguous — still loading, or genuinely null. Use
  `hasValue`/`isLoading` when the distinction matters.
- Always render *something* for `error` — a silently empty screen is worse than
  a message.

## Settings notifiers

`themeModeProvider`, `currencyProvider`, `displayNameProvider`,
`balanceHiddenProvider`, `backupPrefsProvider` declare a throwaway default in
`build()` and are **overridden in `main.dart`** with values already read from
disk — that's why there's no launch flash.

A new persisted setting must be wired in three places: the repo (SharedPreferences),
the notifier, and the `overrides:` list in `main.dart`. Miss the third and it
silently resets on every launch.
