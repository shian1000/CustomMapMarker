import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/coordinate_mapper.dart';
import '../../core/native_tile_renderer.dart';
import '../../core/tile_pyramid.dart';
import '../../data/legend.dart';
import '../../data/map_marker.dart';
import '../../data/map_project.dart';
import '../../data/marker_repository.dart';
import '../../data/providers.dart';
import '../../shared/marker_icons.dart';
import '../../shared/widgets/marker_pin.dart';
import '../marker_editor/marker_details_sheet.dart';
import '../legend/legend_sheet.dart';
import '../maps_list/map_dialogs.dart';
import '../marker_list/marker_list_sheet.dart';
import '../marker_editor/marker_editor_sheet.dart';
import 'clustered_marker_layer.dart';
import 'local_tile_provider.dart';

class MapViewScreen extends ConsumerStatefulWidget {
  const MapViewScreen({super.key, required this.project});

  final MapProject project;

  @override
  ConsumerState<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends ConsumerState<MapViewScreen>
    with TickerProviderStateMixin {
  static const _fitPadding = EdgeInsets.all(16);

  /// How far past 1:1 pixel scale the user may zoom in (2^3 = 8x).
  static const _maxOverZoom = 3.0;

  /// Flying to a marker zooms in at least this far past the whole-map view.
  static const _flyToZoomIn = 2.0;
  static const _flightDuration = Duration(milliseconds: 600);
  static const _focusDuration = Duration(seconds: 2);

  final _controller = MapController();
  late final _mapper = MapCoordinateMapper(
    widthPx: widget.project.widthPx,
    heightPx: widget.project.heightPx,
  );

  late final _tileProvider = widget.project.isTiled
      ? LocalTileProvider(
          tilesDir: widget.project.tilesDir,
          imagePath: widget.project.imagePath,
          pyramid: TilePyramid(
            widthPx: widget.project.widthPx,
            heightPx: widget.project.heightPx,
          ),
          renderer: NativeTileRenderer.isSupported
              ? const NativeTileRenderer()
              : null,
        )
      : null;

  /// Marker waiting for the user to tap its new position.
  MapMarker? _moving;

  MarkerRepository get _markers => ref.read(markerRepositoryProvider);

  CameraFit get _fitImage =>
      CameraFit.bounds(bounds: _mapper.bounds, padding: _fitPadding);

  /// Camera animation started from the marker list.
  AnimationController? _flight;

  /// Marker briefly emphasized after flying to it.
  String? _focusedId;
  Timer? _focusTimer;

  @override
  void dispose() {
    _flight?.dispose();
    _focusTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _rename(String currentName) async {
    final name = await showRenameMapDialog(context, currentName);
    if (name == null || name == currentName) return;
    await ref.read(mapRepositoryProvider).rename(widget.project.id, name);
  }

  Future<void> _openMarkerList(
    List<MapMarker> markers, {
    required int hiddenByFilter,
  }) async {
    final marker = await showMarkerList(
      context,
      markers,
      hiddenByFilter: hiddenByFilter,
    );
    if (marker == null || !mounted) return;
    await _flyTo(_mapper.toLatLng(Offset(marker.x, marker.y)));
    if (!mounted) return;
    _focusTimer?.cancel();
    setState(() => _focusedId = marker.id);
    _focusTimer = Timer(_focusDuration, () {
      if (mounted) setState(() => _focusedId = null);
    });
  }

  /// Smoothly moves the camera to [target], zooming in if the map is shown
  /// too far out to make out the spot. flutter_map has no camera animation of
  /// its own, so this interpolates center and zoom frame by frame.
  /// [zoom] defaults to a close-up of the spot.
  Future<void> _flyTo(LatLng target, {double? zoom}) async {
    final camera = _controller.camera;
    final closeUp = _mapper.fitZoom(camera.nonRotatedSize) + _flyToZoomIn;
    final endZoom = (zoom ?? max(camera.zoom, closeUp)).clamp(
      camera.minZoom ?? double.negativeInfinity,
      camera.maxZoom ?? double.infinity,
    );
    final start = camera.center;
    final startZoom = camera.zoom;

    _flight?.dispose();
    final flight = _flight = AnimationController(
      vsync: this,
      duration: _flightDuration,
    );
    final t = CurvedAnimation(parent: flight, curve: Curves.easeInOutCubic);
    flight.addListener(() {
      _controller.move(
        LatLng(
          _lerp(start.latitude, target.latitude, t.value),
          _lerp(start.longitude, target.longitude, t.value),
        ),
        _lerp(startZoom, endZoom, t.value),
      );
    });
    try {
      await flight.forward().orCancel;
    } on TickerCanceled {
      // Interrupted by the user grabbing the map, or the screen closing.
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  MapLegend get _legend =>
      ref.read(legendProvider(widget.project.id)).value ?? const {};

  /// A marker just given a color that the filter hides would vanish as soon
  /// as it's saved; show that color again instead and say so.
  Future<void> _revealColor(int colorValue) async {
    if (!_legend.isHidden(colorValue)) return;
    await ref
        .read(legendRepositoryProvider)
        .setHidden(widget.project.id, colorValue, false);
    if (!mounted) return;
    final name = _legend.nameOf(colorValue);
    _showMessage(
      name == null
          ? 'Ten kolor był ukryty filtrem – znów jest widoczny.'
          : 'Kolor „$name” był ukryty filtrem – znów jest widoczny.',
    );
  }

  /// Zooms so a cluster's members spread out; if they sit on (nearly) the
  /// same spot, zooms to full resolution, where nothing is clustered.
  Future<void> _zoomToCluster(List<MapMarker> members) {
    final points = [
      for (final m in members) _mapper.toLatLng(Offset(m.x, m.y)),
    ];
    final camera = _controller.camera;
    final fitted = CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.all(MarkerPin.width / 2),
      maxZoom: _mapper.nativeZoom,
    ).fit(camera);
    // Always zoom in by at least one level so the tap visibly does something.
    final zoom = max(fitted.zoom, min(camera.zoom + 1, _mapper.nativeZoom));
    return _flyTo(fitted.center, zoom: zoom);
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
    final draft = await showMarkerEditor(context, colorNames: _legend.names);
    if (draft == null) return;
    await _markers.add(widget.project.id, _mapper.toNormalized(point), draft);
    await _revealColor(draft.colorValue);
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
    final action = await showMarkerDetails(
      context,
      marker,
      colorName: _legend.nameOf(marker.colorValue),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case MarkerAction.edit:
        final draft = await showMarkerEditor(
          context,
          colorNames: _legend.names,
          initial: MarkerDraft(
            label: marker.label,
            description: marker.description,
            colorValue: marker.colorValue,
            icon: marker.icon,
          ),
        );
        if (draft == null) return;
        await _markers.edit(marker.id, draft);
        await _revealColor(draft.colorValue);
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

  Widget _imageLayer(BuildContext context) {
    final project = widget.project;
    final tileMaxZoom = project.tileMaxZoom;
    if (tileMaxZoom == null) {
      return OverlayImageLayer(
        overlayImages: [
          OverlayImage(
            bounds: _mapper.bounds,
            imageProvider: FileImage(File(project.imagePath)),
          ),
        ],
      );
    }
    // flutter_map sizes tiles in logical pixels, so on a 2.6× screen a 256 px
    // tile would be stretched over ~670 physical pixels and look blurry.
    // Request tiles [levelsUp] levels higher and draw them proportionally
    // smaller, so tile pixels roughly match physical pixels.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final levelsUp = min(
      max((log(pixelRatio) / ln2 - 0.05).ceil(), 0),
      min(2, tileMaxZoom),
    );
    return TileLayer(
      tileProvider: _tileProvider!,
      tileBounds: _mapper.bounds,
      tileDimension: TilePyramid.tileSize >> levelsUp,
      zoomOffset: levelsUp.toDouble(),
      minNativeZoom: 0,
      maxNativeZoom: tileMaxZoom - levelsUp,
      // TileLayer hides itself below minZoom, which defaults to 0; the
      // fitted view of a small screen can be slightly below that.
      minZoom: double.negativeInfinity,
      tileDisplay: const TileDisplay.instantaneous(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Live name, so a rename shows up right away.
    final name =
        ref
            .watch(mapsProvider)
            .value
            ?.where((s) => s.map.id == widget.project.id)
            .firstOrNull
            ?.map
            .name ??
        widget.project.name;
    final legend =
        ref.watch(legendProvider(widget.project.id)).value ?? const {};
    final allMarkers =
        ref.watch(markersProvider(widget.project.id)).value ?? const [];
    final markers = [
      for (final m in allMarkers)
        if (!legend.isHidden(m.colorValue)) m,
    ];
    final hiddenByFilter = allMarkers.length - markers.length;
    final moving = _moving;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Legenda i filtr',
            onPressed: () => showLegendSheet(context, widget.project.id),
            icon: Badge(
              // Dot when the filter hides something.
              isLabelVisible: hiddenByFilter > 0,
              child: const Icon(Icons.filter_alt_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Lista znaczników',
            onPressed: moving == null
                ? () => _openMarkerList(markers, hiddenByFilter: hiddenByFilter)
                : null,
            icon: const Icon(Icons.format_list_bulleted),
          ),
          IconButton(
            tooltip: 'Zmień nazwę',
            onPressed: () => _rename(name),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
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
                  onPositionChanged: (_, hasGesture) {
                    // Let the user take over mid-flight.
                    if (hasGesture) _flight?.stop();
                  },
                  onTap: _onTap,
                ),
                children: [
                  _imageLayer(context),
                  ClusteredMarkerLayer(
                    markers: markers,
                    positionOf: (m) => _mapper.toLatLng(Offset(m.x, m.y)),
                    clusterBelowZoom: _mapper.nativeZoom,
                    neverCluster: {?moving?.id, ?_focusedId},
                    onClusterTap: _zoomToCluster,
                    pinBuilder: (m) => MarkerPin(
                      label: m.label,
                      color: Color(m.colorValue),
                      icon: markerIconFor(m.icon)?.icon,
                      highlighted: m.id == moving?.id || m.id == _focusedId,
                      emphasized: m.id == _focusedId,
                      onTap: () => _onMarkerTap(m),
                    ),
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
