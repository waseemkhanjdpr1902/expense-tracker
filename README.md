<h1 align="center">Xpense Tracker</h1>

<p align="center">
  An offline-first personal finance app for Android — expenses, income, loans and
  project budgets, with optional private Google&nbsp;Drive backup.
</p>

<p align="center">
  <a href="https://github.com/saranzafar/expense-tracker-flutter-mobile-app/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/saranzafar/expense-tracker-flutter-mobile-app?style=flat-square" /></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android-3ddc84?style=flat-square" />
  <img alt="Built with Flutter" src="https://img.shields.io/badge/Flutter-3.44-02569B?style=flat-square" />
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" /></a>
</p>

<p align="center">
  <img src="assets/app-images/xpense-tracker-1.jpeg" width="200" />
  <img src="assets/app-images/xpense-tracker-2.jpeg" width="200" />
  <img src="assets/app-images/xpense-tracker-3.jpeg" width="200" />
  <img src="assets/app-images/xpense-tracker-4.jpeg" width="200" />
</p>

## Install

Download the APK for your device from the
**[latest release](https://github.com/saranzafar/expense-tracker-flutter-mobile-app/releases/latest)**.
Most phones need `app-arm64-v8a-release.apk`; `armeabi-v7a` covers 32-bit devices and `x86_64`
covers emulators.

Enable **Install from unknown sources**, then open the file.

> [!WARNING]
> **Upgrading from v1.0.2 or earlier requires an uninstall.** v1.0.3 is signed with a new release
> key, so Android will refuse to install it over the old version — and uninstalling deletes the
> local database, which is the only copy your records have.
>
> Back up first: in the old version, **Settings → Backup → Back up now**. Then uninstall, install
> v1.0.3, sign in and restore. Fresh installs are unaffected.

## Features

**Records** — four types (expense, income, loan given, loan taken) over one shared category pool,
with swipe-to-delete, paginated history and live income / expense / net totals for whatever filter
is active.

**Loans** — track money lent and borrowed, mark it repaid, and keep the history. Every outstanding
loan is visible by default, so a debt from six months ago can't quietly scroll off the screen.

**Projects** — budget, timeline and payment tracking for client work. Payments post as income, so
they raise your balance and appear in Recent Activity. Completion is an explicit decision rather
than a calculation: a project can be delivered while money is owed, or fully paid while work
continues.

**Search** — one global field across records, loans, projects and categories, plus a scoped search
on each list that stacks with the active filters and keeps the totals in agreement. Category names
match too, so "groceries" finds everything filed under it even when the word appears in no
description.

**Backup** — optional Google Drive backup into a private app-data folder that stays invisible in
the Drive UI. It carries your settings as well as your data, refuses to overwrite a newer copy made
on another device, and restores in place without an app restart.

**Design** — Material 3 in light and dark, with the dark theme built on Apple's elevation ramp
rather than pure white on near-black. iOS-style navigation, haptics, and category glyphs derived
from category names.

**Xpy** — a code-drawn pixel cat on the home screen whose mood follows your month's net.

## Privacy

Everything is local by default. Records live in a SQLite database on the device and settings in
`SharedPreferences`; the app is fully usable with no account and no network. Google Sign-In exists
only to enable Drive backup, and the backup goes to a folder scoped to this app that no other
application can read.

## Architecture

Flutter · Riverpod 2 · Drift (SQLite) · fl_chart · `google_sign_in` · `googleapis` · Material 3

```text
lib/
  main.dart      # loads persisted settings before the first frame
  app.dart       # MaterialApp + onboarding gate
  shell/         # 5-tab PageView, floating nav bar, auto-backup triggers
  core/          # theme, motion, currency, date-range and formatting primitives
  data/          # drift database (schema v6), providers, settings repos
  features/      # home · records · loans · projects · search · settings · backup
                 # about · onboarding · mascot (Xpy) · shared widgets
```

## Build from source

```bash
git clone https://github.com/saranzafar/expense-tracker-flutter-mobile-app.git
cd expense-tracker-flutter-mobile-app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Requires the Flutter SDK (Dart `^3.11.5`) and an Android device or emulator. Android is the only
maintained platform.

## Documentation

| | |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [SETUP.md](SETUP.md) | Google Drive backup setup, release signing, keystore recovery |
| [CLAUDE.md](CLAUDE.md) | Architecture, invariants and conventions for contributors |

## License

MIT — see [LICENSE](LICENSE).

**Author:** Saran Zafar — [saranzafar.com](https://saranzafar.com) · [GitHub](https://github.com/saranzafar) · [LinkedIn](https://www.linkedin.com/in/saranzafar)
