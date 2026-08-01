import 'package:flutter/services.dart';

/// One vocabulary for touch feedback.
///
/// Named by *meaning* rather than by platform primitive, so the mapping can be
/// retuned in one place — and so call sites read as intent ("this succeeded")
/// rather than as a device instruction ("vibrate medium").
///
/// **The rule: at most one haptic per user intent.** Never on scroll, never on
/// `PageView` swipe frames, never inside `build()`. Feedback that fires on
/// motion the user didn't deliberately cause reads as a malfunction.
///
/// All five map to Android-native constants and need no permission —
/// `performHapticFeedback` is not the vibrator API.
abstract final class AppHaptics {
  /// Set false to silence every call (a Settings toggle can drive this).
  static bool enabled = true;

  /// Moving between equivalent options: a tab, a filter chip, a segment.
  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// A tap that commits to something: opening a row, tapping add.
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Something completed: a record saved, a payment added, a backup finished.
  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Something destructive or blocking just happened.
  static void warning() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
