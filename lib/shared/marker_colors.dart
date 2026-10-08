import 'package:flutter/material.dart';

/// Palette offered when creating or editing a marker.
const markerColors = <Color>[
  Color(0xFFE53935), // red
  Color(0xFFFB8C00), // orange
  Color(0xFFFDD835), // yellow
  Color(0xFF43A047), // green
  Color(0xFF00897B), // teal
  Color(0xFF1E88E5), // blue
  Color(0xFF3949AB), // indigo
  Color(0xFF8E24AA), // purple
  Color(0xFFD81B60), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF546E7A), // grey
  Color(0xFF212121), // black
];

/// Black or white, whichever reads better on [background].
Color onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;
