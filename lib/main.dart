import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documentsDir = await getApplicationDocumentsDirectory();
  runApp(
    ProviderScope(
      overrides: [documentsDirProvider.overrideWithValue(documentsDir)],
      child: const CustomMapMarkerApp(),
    ),
  );
}
