import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

/// Asks for a single line of text.
///
/// Replaces six near-identical "type a name" dialogs, and fixes a real bug in
/// one of them: `categories_page` built a `TextEditingController` *inside* the
/// dialog's `builder`, so it was recreated on every rebuild (losing cursor
/// position) while `onChanged` maintained a second, competing source of truth.
///
/// The controller here lives in a `StatefulBuilder`'s state, created once —
/// which is safe because it is never disposed early. (Disposing a controller
/// the moment a dialog future completes is what causes the
/// `_dependents.isEmpty is not true` crash documented in `record_form_page`:
/// the field is still rendered during the ~200ms close animation.)
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  String confirmLabel = 'Save',
  int maxLength = 60,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      var value = initial ?? '';
      final controller = TextEditingController(text: value);
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final canSubmit = value.trim().isNotEmpty;
          void submit() {
            if (canSubmit) Navigator.pop(ctx, value.trim());
          }

          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: hint, counterText: ''),
              onChanged: (v) => setLocal(() => value = v),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                // Disabled rather than silently accepting blank input.
                onPressed: canSubmit ? submit : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Confirms something irreversible. The one place a destructive haptic fires.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style: TextStyle(color: ctx.palette.dangerContent)),
        ),
      ],
    ),
  );
  if (ok == true) AppHaptics.warning();
  return ok ?? false;
}
