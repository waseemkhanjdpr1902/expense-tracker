import 'package:flutter/material.dart';

/// Iconography rules for the app.
///
/// > **Every icon is `Icons.*_rounded`.** The only exception is
/// > `Icons.*_outlined`, used exclusively as the *unselected* half of a
/// > selected/unselected pair (currently just the nav bar).
///
/// Material Symbols Rounded is the closest built-in family to SF Symbols —
/// round terminals, even optical weight. The default (sharp) and outlined
/// families are what make an app read as stock Material.
///
/// `test/icon_convention_test.dart` enforces this; it is what stops the app
/// drifting back to three families.
abstract final class AppIcons {
  // ── Navigation: the one legitimate outlined/filled pairing ──────────────
  static const homeOff = Icons.home_outlined;
  static const home = Icons.home_rounded;
  static const recordsOff = Icons.receipt_long_outlined;
  static const records = Icons.receipt_long_rounded;
  static const loansOff = Icons.handshake_outlined;
  static const loans = Icons.handshake_rounded;
  static const projectsOff = Icons.folder_outlined;
  static const projects = Icons.folder_rounded;
  static const settingsOff = Icons.settings_outlined;
  static const settings = Icons.settings_rounded;

  // ── Domain ──────────────────────────────────────────────────────────────
  static const expense = Icons.arrow_upward_rounded;
  static const income = Icons.arrow_downward_rounded;
  static const loanGiven = Icons.handshake_rounded;
  static const loanTaken = Icons.arrow_circle_down_rounded;
  static const category = Icons.sell_rounded;
  static const money = Icons.payments_rounded;
  static const wallet = Icons.account_balance_wallet_rounded;
  static const calendar = Icons.calendar_today_rounded;

  // ── Actions ─────────────────────────────────────────────────────────────
  static const add = Icons.add_rounded;
  static const edit = Icons.edit_rounded;
  /// Outline weight is deliberate here — a solid trash reads as a warning.
  static const delete = Icons.delete_outline_rounded;
  static const close = Icons.close_rounded;
  static const check = Icons.check_rounded;
  static const checkCircle = Icons.check_circle_rounded;
  static const search = Icons.search_rounded;
  static const filter = Icons.tune_rounded;
  static const refresh = Icons.refresh_rounded;
  static const more = Icons.more_vert_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const back = Icons.arrow_back_rounded;
  static const undo = Icons.undo_rounded;
  static const dropdown = Icons.arrow_drop_down_rounded;
  static const openExternal = Icons.open_in_new_rounded;

  // ── Status / empty ──────────────────────────────────────────────────────
  static const noResults = Icons.search_off_rounded;
  static const noFilterMatch = Icons.folder_off_rounded;
  static const person = Icons.person_rounded;
  static const personOff = Icons.person_outline_rounded;
  static const info = Icons.info_rounded;
  static const error = Icons.error_rounded;
  static const lock = Icons.lock_rounded;
  static const visible = Icons.visibility_rounded;
  static const hidden = Icons.visibility_off_rounded;
}

/// Icon size scale. Nothing outside this list.
///
/// Replaces the ad-hoc 10/14/16/18/20/22 sizes that were in use. Note these
/// are *glyph* sizes — container sizes belong to the widget (see `IconBadge`).
abstract final class AppIconSize {
  /// Inline with caption text.
  static const double xs = 14;

  /// Dense trailing affordance (chevrons, clear buttons).
  static const double sm = 16;

  /// Default: list rows, nav bar, badges.
  static const double md = 20;

  /// AppBar actions — Material's own default.
  static const double lg = 24;

  /// Feature badge.
  static const double xl = 32;

  /// Empty-state glyph.
  static const double empty = 40;
}
