import 'dart:async';

import 'package:flutter/foundation.dart';

/// One-shot trailing debounce. Owned by a `State`; call [dispose] from
/// `State.dispose`.
///
/// Matches the plain-`Timer` debounce already used for auto-backup in
/// `home_shell.dart` rather than pulling in a package. Debouncing here — in the
/// widget, before the value reaches a provider key — is what keeps the previous
/// results on screen while typing, instead of flashing an intermediate state.
class Debouncer {
  Debouncer([this.delay = const Duration(milliseconds: 220)]);

  final Duration delay;
  Timer? _timer;

  /// Runs [action] once the caller stops calling for [delay].
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending call and runs [action] now — for submit/enter.
  void flush(VoidCallback action) {
    _timer?.cancel();
    action();
  }

  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
