import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';

void openSettings(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

/// App-wide options, the same for every map.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        children: [
          header('Rysowanie tras i obszarów'),
          SwitchListTile(
            title: const Text('Przyciągaj do znaczników'),
            subtitle: const Text(
              'Stuknięcie blisko znacznika stawia punkt dokładnie na nim',
            ),
            value: settings.snapToMarkers,
            onChanged: notifier.setSnapToMarkers,
          ),
          header('Na mapie'),
          SwitchListTile(
            title: const Text('Nazwy tras'),
            value: settings.showRouteNames,
            onChanged: notifier.setShowRouteNames,
          ),
          SwitchListTile(
            title: const Text('Nazwy obszarów'),
            value: settings.showAreaNames,
            onChanged: notifier.setShowAreaNames,
          ),
        ],
      ),
    );
  }
}
