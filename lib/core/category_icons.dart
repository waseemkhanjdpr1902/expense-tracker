import 'package:flutter/material.dart';

import 'icons.dart';

/// A category's icon, derived from its **name**.
///
/// Deliberately not stored: a picker would mean a schema migration, a change to
/// the Drive backup format, and a backfill for existing rows. Deriving works
/// retroactively on data the user already has *and* on restored backups, for
/// about sixty lines.
///
/// Upgrade path is preserved — if a picker is ever wanted, add `iconKey` to the
/// Categories table and this becomes
/// `iconForCategory(name, override: cat.iconKey)`; every call site survives.
IconData iconForCategory(String? name) {
  if (name == null || name.trim().isEmpty) return AppIcons.category;
  final n = name.toLowerCase();
  for (final (key, icon) in _rules) {
    if (n.contains(key)) return icon;
  }
  return _fallbacks[_stableHash(n) % _fallbacks.length];
}

/// Ordered, most-specific first — the first substring match wins.
const _rules = <(String, IconData)>[
  ('grocer', Icons.local_grocery_store_rounded),
  ('salary', Icons.payments_rounded),
  ('wage', Icons.payments_rounded),
  ('freelance', Icons.laptop_mac_rounded),
  ('rent', Icons.home_work_rounded),
  ('mortgage', Icons.home_work_rounded),
  ('util', Icons.bolt_rounded),
  ('electric', Icons.bolt_rounded),
  ('water', Icons.water_drop_rounded),
  ('gas', Icons.local_gas_station_rounded),
  ('transport', Icons.directions_car_rounded),
  ('fuel', Icons.local_gas_station_rounded),
  ('taxi', Icons.local_taxi_rounded),
  ('dining', Icons.restaurant_rounded),
  ('restaurant', Icons.restaurant_rounded),
  ('food', Icons.restaurant_rounded),
  ('coffee', Icons.local_cafe_rounded),
  ('health', Icons.favorite_rounded),
  ('medic', Icons.medical_services_rounded),
  ('pharm', Icons.medication_rounded),
  ('shop', Icons.shopping_bag_rounded),
  ('cloth', Icons.checkroom_rounded),
  ('educat', Icons.school_rounded),
  ('school', Icons.school_rounded),
  ('course', Icons.school_rounded),
  ('book', Icons.menu_book_rounded),
  ('travel', Icons.flight_rounded),
  ('flight', Icons.flight_rounded),
  ('hotel', Icons.hotel_rounded),
  ('gift', Icons.card_giftcard_rounded),
  ('subscription', Icons.subscriptions_rounded),
  ('invest', Icons.trending_up_rounded),
  ('saving', Icons.savings_rounded),
  ('insur', Icons.shield_rounded),
  ('tax', Icons.account_balance_rounded),
  ('internet', Icons.wifi_rounded),
  ('phone', Icons.smartphone_rounded),
  ('mobile', Icons.smartphone_rounded),
  ('gym', Icons.fitness_center_rounded),
  ('fitness', Icons.fitness_center_rounded),
  ('pet', Icons.pets_rounded),
  ('entertain', Icons.movie_rounded),
  ('movie', Icons.movie_rounded),
  ('game', Icons.sports_esports_rounded),
  ('music', Icons.headphones_rounded),
  ('child', Icons.child_care_rounded),
  ('repair', Icons.build_rounded),
  ('charit', Icons.volunteer_activism_rounded),
  ('donat', Icons.volunteer_activism_rounded),
];

/// Neutral fallbacks — varied enough that unmatched categories don't all look
/// identical, but never random: the choice is a pure function of the name.
const _fallbacks = <IconData>[
  Icons.sell_rounded,
  Icons.category_rounded,
  Icons.bookmark_rounded,
  Icons.local_offer_rounded,
  Icons.interests_rounded,
];

/// FNV-1a. Deliberately not `String.hashCode`, which is not contractually
/// stable across Dart releases — a category's icon silently changing after an
/// SDK bump would be a small but real bug.
int _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}
