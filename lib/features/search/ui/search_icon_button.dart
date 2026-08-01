import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'search_expand.dart';

/// The search affordance. Owns a [GlobalKey] and hands its on-screen rect to
/// [onTap] so the expansion can start from exactly where it sits.
///
/// [chip] renders the `ProfileChip` recipe for the Home header (40dp target
/// around a 36dp circle, surface fill, hairline border); otherwise a standard
/// AppBar [IconButton], which gets a 48dp target for free.
class SearchIconButton extends StatelessWidget {
  const SearchIconButton({
    super.key,
    required this.onTap,
    this.chip = false,
  });

  final void Function(Rect origin) onTap;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final key = GlobalObjectKey(this);

    void handle() {
      final rect = globalRectOf(key);
      if (rect != null) onTap(rect);
    }

    if (!chip) {
      return IconButton(
        key: key,
        tooltip: 'Search',
        icon: const Icon(Icons.search_rounded),
        onPressed: handle,
      );
    }

    return Semantics(
      button: true,
      label: 'Search',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: handle,
          child: SizedBox(
            key: key,
            height: 40,
            width: 40,
            child: Center(
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.surface,
                  border: Border.all(color: context.hairline),
                ),
                child: Icon(Icons.search_rounded,
                    size: 18, color: context.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
