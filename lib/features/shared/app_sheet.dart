import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';

/// One chrome for every bottom sheet.
///
/// The app had eight sheets in two incompatible styles — five with a
/// transparent background and hand-rolled chrome, three using the theme
/// default — and none with a drag handle.
abstract final class AppSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool scrollable = true,
    bool transparent = false,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: scrollable,
        useSafeArea: true,
        showDragHandle: !transparent,
        backgroundColor:
            transparent ? Colors.transparent : context.palette.bgCard,
        elevation: 0,
        clipBehavior: transparent ? Clip.none : Clip.antiAlias,
        shape: transparent
            ? null
            : const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppRadii.hero)),
              ),
        // Material's default is faster and stiffer than the rest of the app.
        sheetAnimationStyle: AnimationStyle(
          duration: AppMotion.slow,
          curve: AppMotion.enter,
          reverseDuration: AppMotion.med,
          reverseCurve: AppMotion.exit,
        ),
        builder: builder,
      );
}
