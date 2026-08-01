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
- Version lives in `pubspec.yaml` (`version: 1.0.2+3`). The UI never hardcodes
  it — `appVersionProvider` reads it via `package_info_plus` at runtime.
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
- Settings notifiers (`themeModeProvider`, `currencyProvider`,
  `displayNameProvider`, `balanceHiddenProvider`, `backupPrefsProvider`) declare
  a throwaway default in `build()` and are overridden in `main.dart` with values
  already read from disk — that's why there's no loading flash on launch. A new
  persisted setting must be wired in **three** places: the repo, the notifier,
  and the `overrides:` list in `main.dart`.

## Data model (drift, `schemaVersion = 6`)

| Table | Notes |
| --- | --- |
| `Records` | The ledger. `type` ∈ `expense · income · loanGiven · loanTaken`. Money is `amountMinor` (**integer minor units — never doubles**). Loan rows carry `counterparty`, `expectedReturnAt`, `returned`, `returnedAt`. |
| `Categories` | One shared pool used by records *and* projects. Deleting a category nulls out references instead of cascading. |
| `Projects` | Name, description, category, `totalAmountMinor`, start/end dates, and `completedAt`. **Completion is an explicit user mark, never derived from payments** — a project can be delivered while money is owed, and fully paid while work continues. `null` = ongoing. |
| `ProjectPayments` | Timeline entries for a project. |

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

- `README.md` — user-facing feature list + changelog. Update on any user-visible
  change; add a changelog entry per release tag.
- `SETUP.md` — Google Cloud / OAuth, keystore, release build steps.
- `docs/superpowers/specs/` — design docs written before larger features. Keep
  the pattern for anything non-trivial.
