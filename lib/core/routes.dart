import 'package:flutter/material.dart';

/// Every page push in the app goes through here, so navigation has one
/// spelling and future changes land in one file.
///
/// Uses [MaterialPageRoute] deliberately: the app's `pageTransitionsTheme`
/// maps every platform to [CupertinoPageTransitionsBuilder], which brings the
/// interactive left-edge back-swipe with it.
///
/// **Back-swipe caveat.** `CupertinoRouteTransitionMixin` disables the gesture
/// when a route's `popDisposition` is `doNotPop` — so adding
/// `PopScope(canPop: false)` to a pushed page silently kills swipe-to-go-back
/// on it, with no error. For unsaved-changes guards use
/// `PopScope(canPop: true, onPopInvokedWithResult:)` instead.
///
/// The gesture is also disabled on the first route, so `HomeShell`'s
/// double-back-to-exit and tab history are unaffected.
///
/// **On Android, the Cupertino edge-swipe never fires.** With gesture
/// navigation (the modern default, `navigation_mode = 2`) the system back
/// gesture owns the screen edges and consumes the touch first. Interactive,
/// finger-tracked back on Android therefore comes from *predictive back*
/// (`android:enableOnBackInvokedCallback="true"` in the manifest), not from
/// this transition. The transition still supplies the slide + parallax for
/// both push and pop.
abstract final class AppRoute {
  static Route<T> page<T>(Widget child, {bool modal = false}) =>
      MaterialPageRoute<T>(builder: (_) => child, fullscreenDialog: modal);

  /// [modal] `true` for *create* flows: iOS slides those up from the bottom
  /// and gives them no back-swipe, because you dismiss a modal rather than
  /// navigating back out of it.
  static Future<T?> push<T>(
    BuildContext context,
    Widget child, {
    bool modal = false,
  }) =>
      Navigator.of(context).push<T>(page<T>(child, modal: modal));

  static Future<T?> replace<T>(BuildContext context, Widget child) =>
      Navigator.of(context).pushReplacement<T, dynamic>(page<T>(child));
}
