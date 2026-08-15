# Changelog

All notable changes to Xpense Tracker. Each version links to its GitHub release,
where the signed APKs are attached.

## Unreleased

### Fixed
- The summary board on Records and Projects, and the first row of Settings, no
  longer start underneath the app bar — Records and Settings were hidden behind
  it, Projects had a gap of empty space instead. They still scroll under the
  bar; they just no longer begin there
- **Glass now actually looks like glass in light mode.** The tint over the blur
  was opaque enough that only a little of what sits behind a bar came through,
  so bars read as flat white. Dark mode is unchanged

## [v1.0.4](https://github.com/saranzafar/expense-tracker-flutter-mobile-app/releases/tag/v1.0.4)

> Installs straight over v1.0.3 — no uninstall, nothing to back up first.

### Added
- **Loan instalments.** Lend someone 5,000 and get it back 2,000 at a time — each
  repayment is recorded against the loan, with the same payment-timeline screen
  projects use. Works in both directions: repayments you receive on money you
  lent, and repayments you make on money you borrowed
- Outstanding is now **what's still owed**, not the full principal, everywhere it
  appears — the loans list, the home summary and the balance
- Loans settle themselves once repayments cover the principal, and you can still
  settle one early if you forgave the rest
- Loan cards show what's left when a loan is partly repaid
- **Filter by several categories at once** on Records, Loans and Projects —
  tap as many as you like and "All" clears the selection. Totals follow the
  selection
- **Glass chrome.** App bars, the floating nav bar and bottom sheets are
  translucent, with your content visibly passing beneath them. Applied only to
  navigation — never over records, balances or anything you need to read
- **Reduce transparency** setting under Appearance, for solid bars and sheets

### Changed
- **Borrowed money now raises your balance instead of lowering it.** Cash you
  borrowed is in your pocket — the debt is real, but it isn't a reduction in what
  you can spend. The old formula subtracted it, which double-counted: the cash
  was never credited on the way in, then the liability was deducted on top.
  **Your balance will change when you update**, by twice the total you have
  outstanding on borrowed loans
- Tapping a loan opens the loan instead of the edit form; edit is on its app bar
- Bottom sheets share one chrome. Five screens had drifted to their own corner
  radius and their own drag handle
- **The dark theme is deeper and no longer grey.** Rebuilt on a cool-tinted
  near-black (`#090C12`) with surfaces stepping 5-8% at a time. Contrast is
  unchanged at ~14:1, so it reads richer without becoming harsh
- Database schema 6 → 7. Existing loans are untouched and simply start with no
  instalments recorded

### Fixed
- Opening a project from global search flashed the page and bounced straight
  back to the results

## [v1.0.3](https://github.com/saranzafar/expense-tracker-flutter-mobile-app/releases/tag/v1.0.3)

> **Breaking for existing installs.** This release is signed with a new release key, so Android
> will not install it over v1.0.2 — the old keystore was lost in a laptop migration and cannot be
> recovered. Back up to Drive from the old version first, then uninstall, install v1.0.3 and
> restore. Fresh installs are unaffected.

### Added
- **Global search** from the Home header across records, loans, projects and categories, plus
  per-page search on Records, Loans and Projects that narrows the current list and keeps the
  totals in agreement with it
- **Projects: mark complete / re-open.** Completion is an explicit decision, not "you've been paid
  in full" — a project can be delivered while money is still owed, or fully paid while work continues
- **Projects: All / Ongoing / Completed filter**, defaulting to Ongoing
- Project cards show the **remaining** amount
- Haptic feedback and press states throughout

### Changed
- **Dark theme rebuilt on Apple's elevation ramp.** The previous theme paired near-black with pure
  white — 19.7:1 measured, beyond even the AAA ceiling, which is what makes a dark screen tiring
  after a few minutes. Text now sits at 14.4:1 and the accent desaturates in dark mode
- **iOS-style navigation** — consistent slide transitions, predictive back, and a record's icon
  flying into its detail page
- **One icon family throughout**; categories derive their own glyph from their name
- Unified empty states and skeleton loading in place of spinner flashes
- **Loans and Projects default to "All" dates.** Loans previously showed only the last 30 days, so
  an unpaid loan from three months ago was invisible on the screen whose whole job is tracking it
- Database schema 5 → 6. Older backups restore fine on this version; a backup made *by* this
  version can't be restored onto an older build until it updates

### Fixed
- Unreadable text on soft-green panels (measured 2.11:1)
- A danger red that already failed WCAG AA at 4.23:1
- List rows had no pressed state at all — the ink splash was disabled app-wide
- A text field inside a dialog builder that lost cursor position on every rebuild
- Project detail showed a stale snapshot after an edit until you navigated away and back

## [v1.0.2](https://github.com/saranzafar/expense-tracker-flutter-mobile-app/releases/tag/v1.0.2)

### Added
- **Xpy**, a code-drawn pixel-cat companion on the home screen. Its mood follows your month's net
  (saving = happy, overspending = worried, quiet = sleepy); it breathes, blinks, looks around,
  twitches its ears, yawns, wags, hops and takes little walks on its own; reacts when your balance
  moves; and cycles expressions each time you tap it
- Home chart: tap the **Income / Expense legend** to hide a line — the chart rescales to the remainder
- **Loans**: filter sheet (type · category · date range) + a Lent / Borrowed / Net summary board
- **Projects**: Budget / Received / Remaining summary board that reacts to the active filter
- **Pull-to-refresh** on Home, Records, Loans and Projects
- Backup now includes app settings (currency, theme, display name, balance visibility)

### Changed
- Project advance and timeline payments post as income — they raise your available balance and show
  in Recent Activity, and editing or deleting either side stays in sync with the other
- Restore is instant, with no app restart
- **UI polish**: tabular figures so numbers don't jitter while animating, softer card depth,
  uppercase overline section labels, staggered home entrance, redesigned record tiles and day-group
  headers with daily net totals

### Fixed
- Auto-backup launch race — it now fires when Google sign-in lands, plus a debounced backup after
  any edit
- Restore clears stale `-wal`/`-shm` files, so a replayed write-ahead log can't corrupt restored data
- Auto-backup conflict guard: skips and warns instead of overwriting a cloud backup newer than this
  device's last upload
- Failed auto-backups are surfaced on the Backup page (network errors treated as transient)

## [v1.0.1](https://github.com/saranzafar/expense-tracker-flutter-mobile-app/releases/tag/v1.0.1)

### Added
- Custom date-range picker on the home chart (daily/monthly buckets auto-selected)
- Income / expense / net totals on both the home chart card and the Records page
- **Projects** — budget tracking with a vertical payment timeline and category + date filters
- **Loan taken** record type with its own section in the Loans tab
- Shared categories across all record types, managed from Settings → Categories
- Infinite-scroll pagination on the Records page (50 records per page)

### Fixed
- Dark mode: chip text, category badge and card surface colours
- Balance card no longer inverts to white in dark mode
- Nav bar pill travels directly from source to target tab (400ms `easeInOutCubic`) instead of
  lighting up every tab in between; swipe tracks the finger frame-perfectly

## [v1.0.0](https://github.com/saranzafar/expense-tracker-flutter-mobile-app/releases/tag/v1.0.0)

Initial release — expense, income and loan-given records, Google Drive backup, 10 currencies, and
light/dark themes.
