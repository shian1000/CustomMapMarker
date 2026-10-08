import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/coordinate_mapper.dart';
import '../../data/map_marker.dart';
import '../../data/map_project.dart';
import '../../data/marker_repository.dart';
import '../../data/providers.dart';
import '../../shared/widgets/marker_pin.dart';
import '../marker_editor/marker_details_sheet.dart';
import '../marker_editor/marker_editor_sheet.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key, required this.project});

  final MapProject project;

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen> {
  static const _fitPadding = EdgeInsets.all(16);

  /// How far past 1:1 pixel scale the user may zoom in (2^3 = 8x).
  static const _maxOverZoom = 3.0;

  final _controller = MapController();
  late final _mapper = MapCoordinateMapper(
    widthPx: widget.project.widthPx,
    heightPx: widget.project.heightPx,
  );

  /// Marker waiting for the user to tap its new position.
  MapMarker? _moving;

  MarkerRepository get _markers => ref.read(markerRepositoryProvider);

  CameraFit get _fitImage =>
      CameraFit.bounds(bounds: _mapper.bounds, padding: _fitPadding);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _controller.camera;
    _controller.move(camera.center, camera.zoom + delta);
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _onLongPress(TapPosition _, LatLng point) async {
    if (_moving != null) return;
    if (!_mapper.contains(point)) {
      _showMessage('Znacznik musi leżeć na mapie.');
      return;
    }
    HapticFeedback.mediumImpact();
    final draft = await showMarkerEditor(context);
    if (draft == null) return;
    await _markers.add(widget.project.id, _mapper.toNormalized(point), draft);
  }

  Future<void> _onTap(TapPosition _, LatLng point) async {
    final moving = _moving;
    if (moving == null) return;
    if (!_mapper.contains(point)) {
      _showMessage('Wybierz miejsce na mapie.');
      return;
    }
    setState(() => _moving = null);
    await _markers.move(moving.id, _mapper.toNormalized(point));
  }

  Future<void> _onMarkerTap(MapMarker marker) async {
    if (_moving != null) return;
    final action = await showMarkerDetails(context, marker);
    if (!mounted || action == null) return;

    switch (action) {
      case MarkerAction.edit:
        final draft = await showMarkerEditor(
          context,
          initial: MarkerDraft(
            label: marker.label,
            description: marker.description,
            colorValue: marker.colorValue,
          ),
        );
        if (draft != null) await _markers.edit(marker.id, draft);
      case MarkerAction.move:
        setState(() => _moving = marker);
      case MarkerAction.delete:
        final markers = _markers;
        await markers.remove(marker.id);
        if (!mounted) return;
        _showMessage(
          'Usunięto „${marker.label}”',
          action: SnackBarAction(
            label: 'Cofnij',
            onPressed: () => markers.restore(marker),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers =
        ref.watch(markersProvider(widget.project.id)).value ?? const [];
    final moving = _moving;

    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fitZoom = _mapper.fitZoom(constraints.biggest);
              return FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  crs: const CrsSimple(),
                  // The fit is applied after the first layout; until then the
                  // camera must already sit inside the constraint below.
                  initialCenter: _mapper.toLatLng(const Offset(0.5, 0.5)),
                  initialZoom: fitZoom,
                  initialCameraFit: _fitImage,
                  cameraConstraint: CameraConstraint.containCenter(
                    bounds: _mapper.bounds,
                  ),
                  minZoom: fitZoom - 1,
                  // Tiny images may already be magnified when fitted.
                  maxZoom: max(_mapper.nativeZoom + _maxOverZoom, fitZoom + 1),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onLongPress: _onLongPress,
                  onTap: _onTap,
                ),
                children: [
                  OverlayImageLayer(
                    overlayImages: [
                      OverlayImage(
                        bounds: _mapper.bounds,
                        imageProvider: FileImage(
                          File(widget.project.imagePath),
                        ),
                      ),
                    ],
                  ),
                  MarkerLayer(
                    alignment: Alignment.topCenter,
                    markers: [
                      for (final m in markers)
                        Marker(
                          key: ValueKey(m.id),
                          point: _mapper.toLatLng(Offset(m.x, m.y)),
                          width: MarkerPin.width,
                          height: MarkerPin.height,
                          child: MarkerPin(
                            label: m.label,
                            color: Color(m.colorValue),
                            highlighted: m.id == moving?.id,
                            onTap: () => _onMarkerTap(m),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          if (moving != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _MoveBanner(
                label: moving.label,
                onCancel: () => setState(() => _moving = null),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _MapControls(
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
              onFit: () => _controller.fitCamera(_fitImage),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveBanner extends StatelessWidget {
  const _MoveBanner({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            const Icon(Icons.open_with),
            const SizedBox(width: 12),
            Expanded(child: Text('Stuknij nowe miejsce dla „$label”')),
            TextButton(onPressed: onCancel, child: const Text('Anuluj')),
          ],
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Przybliż',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Oddal',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove),
          ),
          const Divider(height: 1, indent: 8, endIndent: 8),
          IconButton(
            tooltip: 'Pokaż całą mapę',
            onPressed: onFit,
            icon: const Icon(Icons.fit_screen),
          ),
        ],
      ),
    );
  }
}
