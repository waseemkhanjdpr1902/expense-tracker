/// Normalises a raw search field value into the form used as a provider key.
///
/// Trims, collapses runs of internal whitespace, and returns `null` for blank
/// input — so "is a search active?" is a single null check everywhere, and
/// `'  gro '`, `'gro'` and `'gro  '` all collapse to the *same* provider family
/// entry instead of three.
String? normalizeQuery(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}
