import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Splits [text] into spans, styling every case-insensitive occurrence of
/// [query] with [match]. Pure Dart, no package.
///
/// `Text.rich` with these spans supports `maxLines`/`overflow` exactly like
/// `Text`, and screen readers read the concatenated result normally.
TextSpan highlightSpan(
  String text,
  String? query, {
  required TextStyle base,
  required TextStyle match,
}) {
  final needle = query?.trim().toLowerCase();
  if (needle == null || needle.isEmpty) {
    return TextSpan(text: text, style: base);
  }

  final lower = text.toLowerCase();
  // In a few locales toLowerCase changes length (ß, İ), which would desync
  // indices into the original string. Bail out to plain text rather than
  // slicing at the wrong offsets.
  if (lower.length != text.length) return TextSpan(text: text, style: base);

  final spans = <TextSpan>[];
  var i = 0;
  while (true) {
    final j = lower.indexOf(needle, i);
    if (j < 0) {
      if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
      break;
    }
    if (j > i) spans.add(TextSpan(text: text.substring(i, j)));
    spans.add(
        TextSpan(text: text.substring(j, j + needle.length), style: match));
    i = j + needle.length;
  }
  return TextSpan(children: spans, style: base);
}

/// Emphasis for a matched run — heavier weight plus a soft green wash that
/// reads in both themes.
TextStyle highlightStyle(BuildContext context, TextStyle base) => base.copyWith(
      color: context.ink,
      fontWeight: FontWeight.w800,
      backgroundColor: AppColors.greenSoft,
    );
