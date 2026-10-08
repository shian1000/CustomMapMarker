import 'package:flutter/material.dart';

import 'features/maps_list/maps_list_screen.dart';

class CustomMapMarkerApp extends StatelessWidget {
  const CustomMapMarkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Map Marker',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const MapsListScreen(),
    );
  }
}
