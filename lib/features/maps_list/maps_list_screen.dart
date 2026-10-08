import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/image_utils.dart';
import '../../core/map_naming.dart';
import '../../core/plural.dart';
import '../../data/map_project.dart';
import '../../data/providers.dart';
import '../map_view/map_view_screen.dart';
import 'map_dialogs.dart';

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
      final picked = await ref.read(imageFilePickerProvider).pick();
      if (picked == null || !mounted) return;
      final name = await showNewMapNameDialog(
        context,
        suggestMapName(picked.name, DateTime.now()),
      );
      if (name == null || !mounted) return;

      final map = await _withProgress(
        title: 'Importowanie mapy',
        (onProgress) => ref
            .read(mapRepositoryProvider)
            .importImage(picked.path, name: name, onProgress: onProgress),
      );
      if (mounted) _open(map);
    } on UnsupportedImageException {
      _showMessage('Nie udało się odczytać obrazu. Wybierz plik PNG lub JPG.');
    } catch (e) {
      _showMessage('Import nie powiódł się: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _enableTiling(MapProject map) async {
    try {
      await _withProgress(
        title: 'Poprawianie jakości',
        (onProgress) => ref
            .read(mapRepositoryProvider)
            .enableTiling(map, onProgress: onProgress),
      );
      _showMessage('Mapa „${map.name}” korzysta teraz z kafelków');
    } catch (e) {
      _showMessage('Nie udało się poprawić jakości: $e');
    }
  }

  /// Runs [task] behind a modal progress dialog that closes when it ends.
  Future<T> _withProgress<T>(
    Future<T> Function(void Function(double) onProgress) task, {
    required String title,
  }) async {
    final progress = ValueNotifier<double?>(null);
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(title: title, progress: progress),
    );
    try {
      return await task((p) => progress.value = p);
    } finally {
      navigator.pop();
      progress.dispose();
    }
  }

  Future<void> _rename(MapProject map) async {
    final name = await showRenameMapDialog(context, map.name);
    if (name == null || name == map.name) return;
    await ref.read(mapRepositoryProvider).rename(map.id, name);
  }

  Future<void> _delete(MapSummary summary) async {
    if (!await showDeleteMapDialog(context, summary)) return;
    await ref.read(mapRepositoryProvider).delete(summary.map.id);
    _showMessage('Usunięto mapę „${summary.map.name}”');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        AsyncData(value: []) => const _EmptyState(),
        AsyncData(value: final maps) => GridView.builder(
          // Bottom padding keeps the last row clear of the FAB.
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemCount: maps.length,
          itemBuilder: (context, i) {
            final summary = maps[i];
            return _MapCard(
              key: ValueKey(summary.map.id),
              summary: summary,
              onTap: () => _open(summary.map),
              onRename: () => _rename(summary.map),
              onDelete: () => _delete(summary),
              onEnableTiling:
                  ref.read(mapRepositoryProvider).canEnableTiling(summary.map)
                  ? () => _enableTiling(summary.map)
                  : null,
            );
          },
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Nie masz jeszcze map', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Zaimportuj obraz PNG lub JPG, aby utworzyć mapę.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MapMenuAction { rename, enableTiling, delete }

class _MapCard extends StatelessWidget {
  const _MapCard({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    this.onEnableTiling,
  });

  /// Decode width for thumbnails; keeps large maps cheap to show in the grid.
  static const _thumbnailDecodeWidth = 600;

  final MapSummary summary;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  /// Offered only for large maps imported before tiling existed.
  final VoidCallback? onEnableTiling;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final map = summary.map;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.file(
                File(map.imagePath),
                fit: BoxFit.cover,
                cacheWidth: _thumbnailDecodeWidth,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          map.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          markerCountLabel(summary.markerCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_MapMenuAction>(
                    tooltip: 'Opcje mapy',
                    onSelected: (action) => switch (action) {
                      _MapMenuAction.rename => onRename(),
                      _MapMenuAction.enableTiling => onEnableTiling?.call(),
                      _MapMenuAction.delete => onDelete(),
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _MapMenuAction.rename,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Zmień nazwę'),
                        ),
                      ),
                      if (onEnableTiling != null)
                        const PopupMenuItem(
                          value: _MapMenuAction.enableTiling,
                          child: ListTile(
                            leading: Icon(Icons.hd_outlined),
                            title: Text('Popraw jakość (kafelki)'),
                          ),
                        ),
                      const PopupMenuItem(
                        value: _MapMenuAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Usuń'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.title, required this.progress});

  final String title;

  /// Null until tiling starts; small maps never report progress.
  final ValueListenable<double?> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title),
        content: ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                value == null
                    ? 'Przygotowywanie obrazu…'
                    : 'Duża mapa – dzielenie na kafelki '
                          '(${(value * 100).floor()}%)…',
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: value),
            ],
          ),
        ),
      ),
    );
  }
}
