import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/image_utils.dart';
import '../../data/map_project.dart';
import '../../data/providers.dart';
import '../map_view/map_view_screen.dart';

class MapsListScreen extends ConsumerStatefulWidget {
  const MapsListScreen({super.key});

  @override
  ConsumerState<MapsListScreen> createState() => _MapsListScreenState();
}

class _MapsListScreenState extends ConsumerState<MapsListScreen> {
  bool _importing = false;

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final path = await ref.read(imageFilePickerProvider).pick();
      if (path == null) return;
      final map = await ref.read(mapRepositoryProvider).importImage(path);
      if (mounted) _open(map);
    } on UnsupportedImageException {
      _showError('Nie udało się odczytać obrazu. Wybierz plik PNG lub JPG.');
    } catch (e) {
      _showError('Import nie powiódł się: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _open(MapProject map) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MapViewScreen(project: map)));
  }

  @override
  Widget build(BuildContext context) {
    final maps = ref.watch(mapsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Moje mapy')),
      body: switch (maps) {
        AsyncData(value: []) => const Center(
          child: Text('Zaimportuj obraz, aby utworzyć mapę.'),
        ),
        AsyncData(value: final maps) => ListView.builder(
          itemCount: maps.length,
          itemBuilder: (context, i) =>
              _MapTile(map: maps[i], onTap: () => _open(maps[i])),
        ),
        AsyncError(:final error) => Center(
          child: Text('Nie udało się wczytać map: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate),
        label: const Text('Importuj mapę'),
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({required this.map, required this.onTap});

  final MapProject map;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(map.imagePath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          cacheWidth: 112,
          errorBuilder: (_, _, _) => const SizedBox.square(
            dimension: 56,
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
      title: Text(map.name),
      subtitle: Text('${map.widthPx} × ${map.heightPx} px'),
      onTap: onTap,
    );
  }
}
