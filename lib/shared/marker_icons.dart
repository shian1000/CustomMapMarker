import 'package:flutter/material.dart';

/// An icon a marker can show inside its pin.
@immutable
class MarkerIcon {
  const MarkerIcon(this.key, this.icon, this.label);

  /// Stored in the database and exports; never change an existing key.
  final String key;
  final IconData icon;
  final String label;
}

/// Icons offered in the marker editor, in display order.
///
/// Stored by [MarkerIcon.key] rather than by code point: release builds strip
/// unused glyphs from the icon font, and only icons referenced as constants
/// (like these) are kept, so an IconData rebuilt from a stored code point
/// would render as an empty box.
const markerIcons = <MarkerIcon>[
  MarkerIcon('castle', Icons.castle, 'Zamek'),
  MarkerIcon('fort', Icons.fort, 'Twierdza'),
  MarkerIcon('city', Icons.location_city, 'Miasto'),
  MarkerIcon('village', Icons.cottage, 'Wioska'),
  MarkerIcon('house', Icons.house, 'Dom'),
  MarkerIcon('temple', Icons.church, 'Świątynia'),
  MarkerIcon('inn', Icons.sports_bar, 'Karczma'),
  MarkerIcon('shop', Icons.storefront, 'Sklep'),
  MarkerIcon('forest', Icons.forest, 'Las'),
  MarkerIcon('mountain', Icons.terrain, 'Góry'),
  MarkerIcon('volcano', Icons.volcano, 'Wulkan'),
  MarkerIcon('water', Icons.water_drop, 'Woda'),
  MarkerIcon('ship', Icons.sailing, 'Statek'),
  MarkerIcon('port', Icons.anchor, 'Port'),
  MarkerIcon('camp', Icons.local_fire_department, 'Obóz'),
  MarkerIcon('treasure', Icons.diamond, 'Skarb'),
  MarkerIcon('battle', Icons.shield, 'Bitwa'),
  MarkerIcon('danger', Icons.warning, 'Niebezpieczeństwo'),
  MarkerIcon('creature', Icons.pets, 'Potwory'),
  MarkerIcon('quest', Icons.priority_high, 'Zadanie'),
  MarkerIcon('mystery', Icons.question_mark, 'Zagadka'),
  MarkerIcon('star', Icons.star, 'Ważne'),
  MarkerIcon('flag', Icons.flag, 'Flaga'),
];

/// The icon stored as [key]; null for the plain pin or an unknown key (e.g.
/// from a file made by a newer app version).
MarkerIcon? markerIconFor(String? key) {
  if (key == null) return null;
  for (final icon in markerIcons) {
    if (icon.key == key) return icon;
  }
  return null;
}
