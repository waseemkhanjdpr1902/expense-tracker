# CLAUDE.md

Working guide for this repository. Read this before changing code.

## What this is

**Xpense Tracker** — an offline-first personal finance app for Android. Records
(expense / income / loan given / loan taken), loans, projects with payment
timelines, and an optional Google Drive backup. Everything works with no
account and no network; Google Sign-In exists *only* for backup.

- Dart package name: `xpense_traker` (typo is intentional at this point — it is
  baked into the Android `applicationId` `com.example.xpense_traker`, which is
  the install identity of every shipped release and the package name registered
  on the OAuth clients. **Do not rename it.**)
- Version lives in `pubspec.yaml` (`version: 1.0.4+5`). The UI never hardcodes
  it — `appVersionProvider` reads it via `package_info_plus` at runtime.
- **Signing identity changed at v1.0.3.** The original release keystore was lost
  in a laptop migration, so v1.0.3 onward is signed with a new key and cannot
  install over v1.0.2 — users had to uninstall and restore from backup. Don't
  let it happen a third time: the keystore, its passwords and the OAuth
  fingerprints are the app's identity, not build artifacts. See
  [SETUP.md § 4](SETUP.md).
- Android is the only shipping platform. iOS/macOS/Linux/Windows/web scaffolding
  exists from `flutter create` but is unmaintained (launcher icons and native
  splash are generated for Android only).

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after ANY drift schema change
flutter run                                                # debug on a connected device
flutter analyze
flutter test
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols/<version>
```

Release signing, Google Cloud OAuth setup, and the release checklist live in
[SETUP.md](SETUP.md).

## Layout

```text
lib/
  main.dart          # reads persisted settings, then overrides providers with prefilled values
  app.dart           # MaterialApp + _RootGate (onboarding vs HomeShell)
  shell/home_shell.dart   # 5-tab PageView + frosted floating nav bar + auto-backup triggers
  core/              # cross-feature primitives, no feature imports
    theme.dart       # AppColors / AppRadii / AppSpacing / AppTextStyles + context extension
    motion.dart      # AppMotion tokens, FadeIn, XSwitcher, AnimatedMoney, PressScale
    currency.dart    # CurrencyOption, kCurrencies (10), formatMoney
    date_range.dart  # sealed DateRangeFilter (rolling / calendar year / custom)
    formatters.dart  # shared DateFormat instances
    chart_data.dart  # ChartPeriod, ChartPoint
  data/
    database.dart    # drift tables, migrations, all queries  ← the single source of truth
    database.g.dart  # GENERATED — never edit by hand
    providers.dart   # every Riverpod provider that reads the DB
    settings_repo.dart      # SharedPreferences-backed theme/currency/name/balance-hidden
    onboarding_repo.dart
  features/<feature>/ui/…   # one folder per feature; `data/` subfolder only where it exists (backup)
  features/shared/          # widgets reused across features (DateRangeBar, SummaryBoard, SectionHeader)
  features/mascot/          # Xpy — the code-drawn pixel cat (no image assets)
```

Import direction: `features → data → core`. `core/` must not import from
`features/` or `data/`.

## State management

Riverpod 2, **hand-written providers only**. `riverpod_annotation` /
`riverpod_generator` / `custom_lint` are in `pubspec.yaml` but no `@riverpod`
annotation is used anywhere — the only generated file is `database.g.dart`
(drift). Don't introduce codegen for providers without converting the whole file.

- DB-backed reads are `StreamProvider` / `StreamProvider.family` over drift
  `.watch()` queries, so the UI updates the moment a row changes.
- Family arguments are value classes with hand-written `==`/`hashCode`
  (`RecordsQuery`, `RecordsTotalsQuery`, `LoansQuery`, `ChartDateRange`).
  **If you add a field, update both operators** or the family will leak a new
  provider per rebuild.
- **Collection fields in a key need element-wise equality and a canonical
  order.** `categoryIds` is a `List<String>`, compared with `listEquals` and
  hashed with `Object.hashAll` — Dart's `List ==` is identity, so two equal
  selections built on different rebuilds would be unequal keys. The UI holds a
  `Set` and passes it through `categoryKey()`, which sorts: a `Set` iterates in
  insertion order, so Food-then-Fuel and Fuel-then-Food are the same filter but
  would otherwise be two keys, two cached streams and an `AsyncLoading` flash on
  reorder. Locked by `test/category_filter_test.dart`.
- Settings notifiers (`themeModeProvider`, `currencyProvider`,
  `displayNameProvider`, `balanceHiddenProvider`, `backupPrefsProvider`) declare
  a throwaway default in `build()` and are overridden in `main.dart` with values
  already read from disk — that's why there's no loading flash on launch. A new
  persisted setting must be wired in **three** places: the repo, the notifier,
  and the `overrides:` list in `main.dart`.

## Data model (drift, `schemaVersion = 7`)

| Table | Notes |
| --- | --- |
| `Records` | The ledger. `type` ∈ `expense · income · loanGiven · loanTaken`. Money is `amountMinor` (**integer minor units — never doubles**). Loan rows carry `counterparty`, `expectedReturnAt`, `returned`, `returnedAt`. |
| `Categories` | One shared pool used by records *and* projects. Deleting a category nulls out references instead of cascading. |
| `Projects` | Name, description, category, `totalAmountMinor`, start/end dates, and `completedAt`. **Completion is an explicit user mark, never derived from payments** — a project can be delivered while money is owed, and fully paid while work continues. `null` = ongoing. |
| `ProjectPayments` | Timeline entries for a project. |
| `LoanPayments` | Instalments against a loan (`loanId` → `Records.id`). Works both directions: money coming back on what you lent, money you pay off on what you borrowed. |

**Loan instalments are NOT mirrored into `Records`** — the one place they
deliberately differ from project payments. A project payment is new income
entering your finances, so it needs a record. A loan repayment is your own money
returning: minting an income record would inflate lifetime income *and*
double-count against the balance, since the principal is already carried in
`outstanding*`. Instalments move the outstanding number instead.

**Outstanding is `principal − repaid`, clamped at zero**, computed in
`watchStats`. `returned` is still a real flag, not a derivation: `addLoanPayment`
auto-settles a loan when repayments cover it and `deleteLoanPayment` re-opens it,
but `markLoanReturned` can settle early (you forgave the rest) and that is never
overridden. A settled loan is not outstanding at any amount.

`watchStats` therefore combines **two** streams (records + repaid totals). A
records-only watch leaves the dashboard stale after an instalment.

**`availableBalance` adds borrowed money and subtracts lent money.** Cash you
borrowed is in your pocket; the debt is real but it is not a reduction in
spendable cash. It used to subtract borrowed money, which double-counted it —
harmless while the number could only move once, obviously wrong the moment
repayments could move it downward.

**The project-payment ↔ income invariant.** Every `ProjectPayments` row has a
mirrored `Records` row of type `income` whose `projectPaymentId` points back at
it. That's what makes project money show up in the balance, the chart and Recent
Activity. All the paths that maintain it are in `database.dart`:
`addProjectPayment`, `deleteProjectPayment`, `deleteRecord` (deletes the payment
when its income record goes), `deleteProject`, and
`syncProjectPaymentFromRecord` (edit from the Records screen). Touch one side,
check the other.

Migration rules: bump `schemaVersion`, add a `if (from < N)` block, regenerate
(`build.yaml` disables the unused riverpod codegen builder, which otherwise
fails the whole run on modern Dart syntax).
The v5 step backfills income records for pre-existing project payments — new
migrations should be similarly data-safe, because users restore old backups and
`restoreFromDrive` refuses any backup whose `schemaVersion` is *newer* than the
installed app.

`watchStats()` loads all records and folds them in Dart rather than doing SQL
aggregates. Fine at personal-ledger scale; revisit if that ever changes.

## Backup

`features/backup/data/` — three layers:

- `google_auth.dart` — `signInSilently()` is only ever called when the user has
  opted in (`backupPrefs.enabled`). Keep it that way; the app must stay usable
  with no Google account.
- `drive_client.dart` — single file `xpense-backup.sqlite` in the Drive
  **appDataFolder** (invisible in the user's Drive UI). Metadata (schema
  version, timestamp, record count, app version, **and app settings**) rides in
  the file's `description` field as JSON.
- `backup_repo.dart` — orchestration. Snapshots via `VACUUM INTO` (consistent
  copy without closing the live DB), and on restore deletes the stale
  `-wal`/`-shm` siblings before swapping the file in — skipping that lets SQLite
  replay a stale write-ahead log over restored data and corrupt it. Restore ends
  with `ref.invalidate(databaseProvider)` so no app restart is needed.
- Auto-backup is triggered from `home_shell.dart` in four places: post-first-frame,
  when silent sign-in lands (`googleAuthProvider` listener — this one fixes the
  original launch race), on reconnect, and debounced 2 min after any data change
  (`dataChangeProvider`), plus on app pause. `autoBackupIfDue` throttles by
  `minInterval` and **refuses to overwrite a cloud copy newer than this device's
  last upload** (`remoteNewer`), prompting a restore instead.

## Search

`lib/features/search/` — global search (a full-screen route from the Home
header) and the scoped in-AppBar search on Records, Loans and Projects.

- **Text matching uses SQLite `instr()`, never `LIKE`.** `LIKE '%q%'` would
  treat `%` and `_` *in user input* as wildcards — the demo data contains
  "Advance — 30%", so searching `30%` would match every row — and drift 2.21's
  `like()` exposes no ESCAPE clause. `instr` has no pattern language, so there
  is nothing to escape. Locked by `test/record_search_test.dart`; don't "fix"
  it back to LIKE.
- Category *names* can't be matched in one WHERE (no joins anywhere in this
  codebase). Providers resolve matching ids via `matchingCategoryIds(ref, q)`
  and pass `categoryIdsIn` to `watchRecords`.
- `projectPayments.note` is deliberately **not** searched — that text is already
  mirrored into the income record, so searching it would show every payment
  twice.
- Search-keyed families are `autoDispose` (free text = unbounded key space).
  The cost is that a new key starts in `AsyncLoading`, so pages keep the last
  good value and dim to 55% instead of flashing a spinner.
- Queries are normalised with `normalizeQuery` and debounced 220ms in the
  widget, so `' gro '` and `'gro'` share one provider entry.
- Deep-links from global search use `pendingSearchProvider` with **`ref.watch`,
  not `ref.listen`** — the shell's `PageView` builds pages lazily, so a page
  that has never been built would miss a `listen`-only change.
- `ExpandReveal` (`search_expand.dart`) clips a child laid out at its final
  size rather than scaling it — that's why text doesn't squash mid-transition.
  Both the full-screen route and the in-AppBar field use it, which is what makes
  them read as one gesture.

## Design system

Everything visual is token-driven. Adding a raw colour, duration or icon
outside these files is a regression — three tests and a grep guard exist to
catch it.

**Colour — `lib/core/theme.dart`.** `DarkTuning` / `LightTuning` are the dial:
one base colour, a lerp ramp, label alphas, and accent shift factors. A single
`AppPalette.of(brightness)` derives every colour from them; `AppColorsX`
(`context.ink`, `context.hairline`, …) is a facade over it so the ~326 legacy
call sites keep working. New code should prefer `context.palette`.

- The dark base is Apple's elevated ramp (`#1C1C1E` → `#2C2C2E` → `#3A3A3C`)
  and text is `#EBEBF5`, **not** pure white — white on near-black is 19.7:1 and
  physically uncomfortable for sustained use.
- The accent **derives** from `AppBrand.green`: desaturated and dimmed in dark.
  Change the brand colour and everything re-derives.
- `accentSoft` and `mascotBody` are **opaque**, blended once. Translucent fills
  inherit whatever is behind them — that caused unreadable 2.11:1 text, and a
  visible grid over the pixel-cat where its cell edges double-blended.
- Depth in dark comes from the surface ramp, not shadows, which barely read.
- `test/palette_contrast_test.dart` asserts every foreground/background pair
  the palette claims, and mechanically guards "light mode must not move".

**Motion — `lib/core/motion.dart`.** `AppMotion.fast/med/slow/expand/page`,
`enter/exit/emphasized`, press scales, and `staggerDelay(i)` (30ms, capped at 8
— uncapped, row 40 waits 1.2s and reads as broken).

**Routes — `lib/core/routes.dart`.** All pushes go through `AppRoute`. Every
platform uses `CupertinoPageTransitionsBuilder`. Note the Cupertino edge-swipe
does *not* fire on Android — gesture navigation owns the edges — so interactive
back comes from predictive back, enabled in the manifest.

**Hero — `lib/core/hero.dart`.** Tags are namespaced by `HeroScope` because
`RecordTile` renders in Home, Records *and* search, and Home/Records are
adjacent `PageView` children of one route. A missing scope yields a null tag
and no animation, never a crash.

**Icons — `lib/core/icons.dart`.** Everything is `Icons.*_rounded`; `_outlined`
only for the unselected half of a pair (the nav bar). `AppIconSize` is the only
size scale. `iconForCategory(name)` derives a category glyph from its name — no
schema change, works on restored backups. `test/icon_convention_test.dart`
enforces the family.

**Shared UI — `lib/features/shared/`.** `EmptyState` (one component, was seven),
`AppSheet` (one chrome, was two), `promptForText`/`confirmDestructive` (was six
near-identical dialogs), and `DelayedVisible`/`SkeletonRows` — local SQLite
reads return in single-digit ms, so a spinner is a flash, not information.

**Haptics — `lib/core/haptics.dart`.** `selection/light/success/warning`, named
by meaning. At most one per user intent; never on scroll, swipe frames or in
`build()`.

**Glass — `lib/core/glass.dart`.** Translucent chrome, retuned from
`GlassTuning` alone. Three rules, none of them stylistic:

- **Navigation layer only.** App bars, the nav bar, sheets. Apple: *"Don't use
  Liquid Glass in the content layer… can result in a confusing visual
  hierarchy."* A record row, a balance, a totals strip or any card holding a
  number is content. The hero card looks like a candidate and isn't — it's a
  list child that scrolls with content, so there is nothing behind it to
  refract and "glass" there would be a painted-on gradient.
- **Regular, never clear.** The see-through look is Apple's *clear* variant,
  prescribed *"only"* for surfaces over photo and video. Everything here is
  text-heavy, which is what regular exists for.
- **The fill must stay opaque enough to bound its own contrast.** This is the
  whole reason `glassExtremes()` exists: a free-floating translucent surface
  inherits its background, so its contrast becomes a function of scroll
  position and cannot be asserted — the failure that produced 2.11:1 text
  here once, and ~1.5:1 in shipped iOS 26. `glass_contrast_test.dart` asserts
  every foreground against the fill composited over **both** black and white,
  and fails if the fill gets transparent enough for the backdrop to dominate.

Implementation notes worth keeping: blur and saturation are **one composed
`ImageFilter`** (nesting two `BackdropFilter`s buys a second full-screen
save-layer and nothing else); saturation is restored ~18% because blur averages
colour toward grey; the rim inverts between themes (white bright-at-top in
dark; black strongest-at-bottom in light, where a white rim on a near-white
fill is invisible); and `rim: false` wherever a surface's edges run off-screen.

A glass app bar needs `extendBodyBehindAppBar: true` **and** the top inset
moved out of `SafeArea` into the scroll view's padding — with `SafeArea(top:
true)` rows stop below the bar instead of passing under it, and glass with
nothing behind it is an expensive flat fill.

**Glass is always on. There is no in-app switch**, and don't reintroduce one —
it existed, and the only thing it reliably did was leave the effect switched off
on a device by accident. The opaque path is now reached solely through the OS
high-contrast / accessible-navigation flags, which are an accommodation rather
than taste: someone who asked the system for high contrast asked every app on
it. `glassDisabled(context)` reads those and nothing else.

**Refraction — `shaders/liquid_glass.frag`.** The blur alone reads as frosted,
not as a solid pane; what sells the solid is light bending at the edge. The
shader treats the surface as a rounded-rect SDF, takes the normal from its
gradient, and displaces the backdrop lookup along that normal with a weight that
is zero in the centre and peaks just inside the rim. It also draws the specular
highlight, so `_GlassPainter` skips its own rim whenever refraction is active.

Order is blur → bend, composed into one `ImageFilter`: refracting a *sharp*
backdrop shows the displacement as a seam instead of as thickness. Keep the
distortion in the edge band — warping the whole surface is Apple's `clear`
variant, and over a screen of numbers it fights the text.

`ImageFilter.shader` requires Impeller, so `LiquidGlassProgram.ensureLoaded()`
runs before the first frame in `main()` and a failure leaves the program null,
which drops every surface back to the plain blur plus painted rim. `GlassSurface`
is stateful purely to own one `FragmentShader` for its lifetime —
`fragmentShader()` allocates GPU-side memory and the widget rebuilds while the
list behind it scrolls.

## Conventions

- **Money is always `int` minor units.** Format only at the render edge via
  `formatMoney` / `AnimatedMoney`. Never store or arithmetic on doubles.
- Use the tokens: `AppSpacing`, `AppRadii`, `AppColors`, `AppTextStyles`,
  `AppMotion`. Colors that must flip with the theme come from the
  `BuildContext` extension (`context.ink`, `context.inkMuted`,
  `context.cardSurface`, `context.hairline`, `context.softShadow`) — not from
  `Theme.of(context).colorScheme` ad hoc.
- Every text style carries `FontFeature.tabularFigures()` so animated numbers
  don't jitter. Keep that if you add a style.
- Both themes, always. Check any new surface in light *and* dark.
- Each main tab is its own `Scaffold` with a `RefreshIndicator`; tab pages that
  hold filter state use `AutomaticKeepAliveClientMixin`.
- Records list paginates by raising the `limit` on the family query
  (`_pageSize = 50`); totals come from a separate **unlimited** provider
  (`filteredTotalsProvider`) so they stay correct regardless of how much has
  been scrolled.
- Known crash class in this codebase: reading `context`-dependent values inside
  `fl_chart` builders or inside dialogs created after the widget is disposed
  (see the `_dependents crash` fixes in git history). Extract colors *before*
  building the chart; don't hold a `TextEditingController` in the add-category
  dialogs.

## Testing

`test/widget_test.dart` is a single smoke test (fresh install → onboarding
appears). There is no wider suite — if you change boot, onboarding, or provider
overrides, run it; if you add data logic, prefer testing it against
`AppDatabase.forTesting(...)` with an in-memory executor.

## Skills

Detailed working rules live in `.claude/skills/` and load on demand, so they cost
nothing until relevant:

| Skill | Covers |
| --- | --- |
| `flutter-ui` | Design tokens, theming, light/dark parity, widget vocabulary |
| `flutter-motion` | Animation choice, controller lifecycle, transitions, stagger |
| `flutter-performance` | Frame budget, rebuild scoping, lists, paint costs |
| `flutter-accessibility` | Tap targets, semantics, text scaling, contrast |
| `flutter-riverpod` | Provider patterns, family key equality, autoDispose |
| `/ui-check` | Pre-ship checklist for UI work (invoke by name) |

## Docs to keep in sync

- `README.md` — the shop window: what the app is, how to install it, how it's
  built. Prose over bullet dumps, and **no changelog** — that moved to its own
  file precisely because release notes were crowding out the description.
- `CHANGELOG.md` — one section per release tag, grouped Added / Changed / Fixed.
  Add an entry for every user-visible change; the GitHub release notes are
  written from it.
- `SETUP.md` — Google Cloud / OAuth, keystore, release build steps, and the
  machine-migration recovery playbook (§ 4).
- `docs/superpowers/specs/` — design docs written before larger features. Keep
  the pattern for anything non-trivial.
