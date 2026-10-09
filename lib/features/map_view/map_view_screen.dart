import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/coordinate_mapper.dart';
import '../../core/native_tile_renderer.dart';
import '../../core/tile_pyramid.dart';
import '../../data/legend.dart';
import '../../data/map_marker.dart';
import '../../data/map_project.dart';
import '../../data/map_shape.dart';
import '../../data/settings.dart';
import '../../data/map_transfer.dart';
import '../../data/marker_repository.dart';
import '../../data/providers.dart';
import '../../shared/marker_icons.dart';
import '../../shared/widgets/marker_pin.dart';
import '../marker_editor/marker_details_sheet.dart';
import '../../core/plural.dart';
import '../legend/legend_sheet.dart';
import '../settings/settings_screen.dart';
import '../shape_editor/shape_details_sheet.dart';
import '../shape_editor/shape_editor_sheet.dart';
import '../maps_list/map_dialogs.dart';
import '../marker_list/marker_list_sheet.dart';
import '../marker_editor/marker_editor_sheet.dart';
import 'clustered_marker_layer.dart';
import 'map_snapshot.dart';
import 'shape_layers.dart';
import 'shape_point_handles.dart';
import 'snapshot_options_dialog.dart';
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

  /// Kind of the route or area being drawn, null when not drawing.
  ShapeKind? _drawingKind;

  /// Points placed so far while drawing, in map coordinates.
  final _drawingPoints = <LatLng>[];

  /// Markers on screen in the last build, for snapping drawn points.
  List<MapMarker> _visibleMarkers = const [];

  /// While drawing, a tap within this distance of a marker lands on it.
  static const _snapRadius = 32.0;

  /// Route or area whose points are being edited, null otherwise.
  MapShape? _editingShape;

  /// Working copy of [_editingShape]'s points, saved on "Gotowe".
  final _editPoints = <LatLng>[];

  /// Point selected (tapped) while editing, e.g. to delete it.
  int? _selectedPoint;

  /// Taps on routes and areas, reported by their layers.
  final _routeHits = ValueNotifier<LayerHitResult<String>?>(null);
  final _areaHits = ValueNotifier<LayerHitResult<String>?>(null);

  /// The last built shapes, to look up a tapped one by id.
  List<MapShape> _shapes = const [];

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
    _routeHits.dispose();
    _areaHits.dispose();
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

  Future<void> _saveImage(
    String name, {
    required List<MapMarker> allMarkers,
    required List<MapMarker> visibleMarkers,
  }) async {
    final options = await showSnapshotOptionsDialog(
      context,
      filterActive: visibleMarkers.length < allMarkers.length,
    );
    if (options == null || !mounted) return;

    final region = switch (options.area) {
      SnapshotArea.wholeMap => const Rect.fromLTWH(0, 0, 1, 1),
      SnapshotArea.visible => _visibleRegion(),
    };
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Expanded(child: Text('Tworzenie obrazu…')),
            ],
          ),
        ),
      ),
    );
    try {
      final String path;
      try {
        final png = await renderMapSnapshot(
          project: widget.project,
          markers: options.skipHidden ? visibleMarkers : allMarkers,
          region: region,
          renderer: NativeTileRenderer.isSupported
              ? const NativeTileRenderer()
              : null,
        );
        final dir = Directory(
          p.join(ref.read(documentsDirProvider).path, 'transfer', 'image'),
        );
        if (await dir.exists()) await dir.delete(recursive: true);
        await dir.create(recursive: true);
        path = p.join(dir.path, '${MapTransfer.safeFileName(name)}.png');
        await File(path).writeAsBytes(png);
      } finally {
        navigator.pop();
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/png')],
          title: name,
        ),
      );
    } catch (e) {
      if (mounted) _showMessage('Nie udało się zapisać obrazu: $e');
    }
  }

  /// The part of the image currently on screen, normalized to 0..1.
  Rect _visibleRegion() {
    final bounds = _controller.camera.visibleBounds;
    final topLeft = _mapper.toNormalized(bounds.northWest);
    final bottomRight = _mapper.toNormalized(bounds.southEast);
    return Rect.fromPoints(
      topLeft,
      bottomRight,
    ).intersect(const Rect.fromLTWH(0, 0, 1, 1));
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

  /// Moving a marker, drawing or editing points: modes that use taps on the
  /// map for themselves.
  bool get _inMode =>
      _moving != null || _drawingKind != null || _editingShape != null;

  Future<void> _onLongPress(TapPosition _, LatLng point) async {
    if (_inMode) return;
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

  Future<void> _onTap(TapPosition tap, LatLng point) async {
    if (_editingShape != null) {
      setState(() => _selectedPoint = null);
      return;
    }
    if (_drawingKind != null) {
      if (!_mapper.contains(point)) {
        _showMessage('Punkt musi leżeć na mapie.');
        return;
      }
      setState(() => _drawingPoints.add(_snapToMarker(tap, point)));
      return;
    }
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
    if (_drawingKind != null) {
      // Tapping a pin while drawing means "go through this place".
      setState(
        () => _drawingPoints.add(_mapper.toLatLng(Offset(marker.x, marker.y))),
      );
      return;
    }
    if (_moving != null || _editingShape != null) return;
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

  /// [point], or the nearest visible marker if one is within [_snapRadius]
  /// on screen and snapping is on.
  LatLng _snapToMarker(TapPosition tap, LatLng point) {
    final tapAt = tap.relative;
    if (tapAt == null || !ref.read(settingsProvider).snapToMarkers) {
      return point;
    }
    final camera = _controller.camera;
    LatLng? nearest;
    var nearestDistance = _snapRadius;
    for (final m in _visibleMarkers) {
      final at = _mapper.toLatLng(Offset(m.x, m.y));
      final distance = (camera.latLngToScreenOffset(at) - tapAt).distance;
      if (distance <= nearestDistance) {
        nearest = at;
        nearestDistance = distance;
      }
    }
    return nearest ?? point;
  }

  /// [point] snapped to a marker within [_snapRadius] of [screen], if
  /// snapping is on; used when a dragged point is let go.
  LatLng _snapAt(Offset screen, LatLng point) {
    if (!ref.read(settingsProvider).snapToMarkers) return point;
    final camera = _controller.camera;
    for (final m in _visibleMarkers) {
      final at = _mapper.toLatLng(Offset(m.x, m.y));
      if ((camera.latLngToScreenOffset(at) - screen).distance <= _snapRadius) {
        return at;
      }
    }
    return point;
  }

  LatLng _clampToImage(LatLng point) {
    final n = _mapper.toNormalized(point);
    return _mapper.toLatLng(Offset(n.dx.clamp(0, 1), n.dy.clamp(0, 1)));
  }

  Future<void> _onShapeTap(LayerHitResult<String>? hit) async {
    final id = hit?.hitValues.firstOrNull;
    if (id == null || _inMode) return;
    final shape = _shapes.where((s) => s.id == id).firstOrNull;
    if (shape == null) return;

    final action = await showShapeDetails(
      context,
      shape,
      colorName: _legend.nameOf(shape.colorValue),
    );
    if (!mounted || action == null) return;
    final shapes = ref.read(shapeRepositoryProvider);
    switch (action) {
      case ShapeAction.edit:
        final style = await showShapeEditor(
          context,
          kind: shape.kind,
          initial: shape.style,
          colorNames: _legend.names,
        );
        if (style == null) return;
        await shapes.updateStyle(shape.id, style);
        await _revealColor(style.colorValue);
      case ShapeAction.editPoints:
        setState(() {
          _editingShape = shape;
          _selectedPoint = null;
          _editPoints
            ..clear()
            ..addAll(shape.points.map(_mapper.toLatLng));
        });
      case ShapeAction.delete:
        await shapes.remove(shape.id);
        if (!mounted) return;
        final kind = shape.kind == ShapeKind.route ? 'trasę' : 'obszar';
        _showMessage(
          shape.name == null
              ? 'Usunięto $kind'
              : 'Usunięto $kind „${shape.name}”',
          action: SnackBarAction(
            label: 'Cofnij',
            onPressed: () => shapes.restore(shape),
          ),
        );
    }
  }

  void _stopEditingPoints() => setState(() {
    _editingShape = null;
    _editPoints.clear();
    _selectedPoint = null;
  });

  Future<void> _saveEditedPoints() async {
    final shape = _editingShape;
    if (shape == null) return;
    await ref.read(shapeRepositoryProvider).updatePoints(shape.id, shape.kind, [
      for (final p in _editPoints) _mapper.toNormalized(p),
    ]);
    if (mounted) _stopEditingPoints();
  }

  void _deleteSelectedPoint() {
    final index = _selectedPoint;
    final shape = _editingShape;
    if (index == null || shape == null) return;
    if (_editPoints.length <= shape.kind.minPoints) return;
    setState(() {
      _editPoints.removeAt(index);
      _selectedPoint = null;
    });
  }

  void _startDrawing(ShapeKind kind) => setState(() {
    _moving = null;
    _drawingKind = kind;
    _drawingPoints.clear();
  });

  void _stopDrawing() => setState(() {
    _drawingKind = null;
    _drawingPoints.clear();
  });

  Future<void> _finishDrawing() async {
    final kind = _drawingKind;
    if (kind == null || _drawingPoints.length < kind.minPoints) return;
    final style = await showShapeEditor(
      context,
      kind: kind,
      colorNames: _legend.names,
    );
    // Dismissing the editor goes back to drawing, points intact.
    if (style == null || !mounted) return;
    await ref.read(shapeRepositoryProvider).add(widget.project.id, kind, [
      for (final p in _drawingPoints) _mapper.toNormalized(p),
    ], style);
    if (!mounted) return;
    _stopDrawing();
    await _revealColor(style.colorValue);
  }

  List<Widget> _shapeLayers(List<MapShape> allShapes, AppSettings settings) {
    final editing = _editingShape;
    // The shape being edited is drawn from its working copy instead.
    final shapes = [
      for (final s in allShapes)
        if (s.id != editing?.id) s,
    ];
    final interactive = !_inMode;
    List<LatLng> latLngs(MapShape s) => [
      for (final p in s.points) _mapper.toLatLng(p),
    ];
    final areas = [
      for (final s in shapes)
        if (s.kind == ShapeKind.area)
          areaPolygon(
            latLngs(s),
            s.style,
            hitValue: s.id,
            showName: settings.showAreaNames,
          ),
    ];
    final routes = [
      for (final s in shapes)
        if (s.kind == ShapeKind.route) s,
    ];
    final routeLabels = [
      if (settings.showRouteNames)
        for (final r in routes)
          if (r.name case final name?)
            routeLabel(r.id, midpointAlong(latLngs(r)), name),
    ];
    return [
      if (areas.isNotEmpty)
        _tappable(
          interactive,
          _areaHits,
          PolygonLayer<String>(
            polygons: areas,
            hitNotifier: interactive ? _areaHits : null,
          ),
        ),
      if (routes.isNotEmpty)
        _tappable(
          interactive,
          _routeHits,
          PolylineLayer<String>(
            hitNotifier: interactive ? _routeHits : null,
            // Easier to hit a thin line with a finger.
            minimumHitbox: 20,
            polylines: [
              for (final r in routes)
                routePolyline(latLngs(r), r.style, hitValue: r.id),
            ],
          ),
        ),
      if (routeLabels.isNotEmpty) MarkerLayer(markers: routeLabels),
    ];
  }

  /// Makes a shape layer open the tapped shape's details, outside modes.
  Widget _tappable(
    bool interactive,
    ValueNotifier<LayerHitResult<String>?> hits,
    Widget layer,
  ) => interactive
      ? GestureDetector(onTap: () => _onShapeTap(hits.value), child: layer)
      : layer;

  /// The shape whose points are being edited, with handles to change them.
  List<Widget> _editingLayers(MapShape shape) {
    final points = _editPoints;
    final color = Color(shape.colorValue);
    return [
      if (shape.kind == ShapeKind.area)
        PolygonLayer(
          polygons: [areaPolygon(points, shape.style, showName: false)],
        )
      else
        PolylineLayer(polylines: [routePolyline(points, shape.style)]),
      ShapePointHandles(
        points: points,
        closed: shape.kind == ShapeKind.area,
        color: color,
        selected: _selectedPoint,
        onSelect: (i) => setState(() => _selectedPoint = i),
        onMove: (i, to) => setState(() {
          _editPoints[i] = _clampToImage(to);
          _selectedPoint = i;
        }),
        onMoveEnd: (i, screen) =>
            setState(() => _editPoints[i] = _snapAt(screen, _editPoints[i])),
        onInsert: (i, at) => setState(() {
          _editPoints.insert(i, at);
          _selectedPoint = i;
        }),
      ),
    ];
  }

  /// The shape being drawn and handles on its points.
  List<Widget> _drawingLayers(BuildContext context, ShapeKind kind) {
    final color = Theme.of(context).colorScheme.primary;
    final preview = ShapeStyle(
      colorValue: color.toARGB32(),
      dashed: true,
      fillOpacity: 0.2,
    );
    final points = _drawingPoints;
    return [
      if (kind == ShapeKind.area && points.length >= 3)
        PolygonLayer(polygons: [areaPolygon(points, preview, showName: false)])
      else if (points.length >= 2)
        PolylineLayer(polylines: [routePolyline(points, preview)]),
      MarkerLayer(
        markers: [
          for (final (i, p) in points.indexed)
            Marker(
              point: p,
              width: 18,
              height: 18,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // The latest point stands out, since Undo removes it.
                    color: i == points.length - 1 ? color : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    ];
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
    final drawingKind = _drawingKind;
    final shapes =
        ref.watch(shapesProvider(widget.project.id)).value ?? const [];
    final settings = ref.watch(settingsProvider);
    final editingShape = _editingShape;
    _visibleMarkers = markers;
    _shapes = shapes;

    return PopScope(
      // Back leaves drawing or moving first, not the map.
      canPop: moving == null && drawingKind == null && editingShape == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (drawingKind != null) _stopDrawing();
        if (editingShape != null) _stopEditingPoints();
        if (moving != null) setState(() => _moving = null);
      },
      child: Scaffold(
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
              onPressed: !_inMode
                  ? () =>
                        _openMarkerList(markers, hiddenByFilter: hiddenByFilter)
                  : null,
              icon: const Icon(Icons.format_list_bulleted),
            ),
            PopupMenuButton<_MapAction>(
              tooltip: 'Więcej',
              onSelected: (action) => switch (action) {
                _MapAction.rename => _rename(name),
                _MapAction.saveImage => _saveImage(
                  name,
                  allMarkers: allMarkers,
                  visibleMarkers: markers,
                ),
                _MapAction.settings => openSettings(context),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MapAction.rename,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Zmień nazwę'),
                  ),
                ),
                PopupMenuItem(
                  value: _MapAction.saveImage,
                  child: ListTile(
                    leading: Icon(Icons.image_outlined),
                    title: Text('Zapisz jako obraz'),
                  ),
                ),
                PopupMenuItem(
                  value: _MapAction.settings,
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Ustawienia'),
                  ),
                ),
              ],
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
                    maxZoom: max(
                      _mapper.nativeZoom + _maxOverZoom,
                      fitZoom + 1,
                    ),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    interactionOptions: const InteractionOptions(
                      // Not toggling doubleTapZoom while drawing: flutter_map
                      // 8.3 stops reporting taps when that flag changes.
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
                    ..._shapeLayers(shapes, settings),
                    if (drawingKind != null)
                      ..._drawingLayers(context, drawingKind),
                    if (editingShape != null) ..._editingLayers(editingShape),
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
            if (editingShape != null)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: _EditPointsBanner(
                  onDeletePoint:
                      _selectedPoint != null &&
                          _editPoints.length > editingShape.kind.minPoints
                      ? _deleteSelectedPoint
                      : null,
                  onCancel: _stopEditingPoints,
                  onDone: _saveEditedPoints,
                ),
              ),
            if (drawingKind != null)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: _DrawBanner(
                  kind: drawingKind,
                  points: _drawingPoints.length,
                  onUndo: _drawingPoints.isEmpty
                      ? null
                      : () => setState(_drawingPoints.removeLast),
                  onCancel: _stopDrawing,
                  onDone: _drawingPoints.length >= drawingKind.minPoints
                      ? _finishDrawing
                      : null,
                ),
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
                onDraw: !_inMode ? _startDrawing : null,
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
                onFit: () => _controller.fitCamera(_fitImage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPointsBanner extends StatelessWidget {
  const _EditPointsBanner({
    required this.onDeletePoint,
    required this.onCancel,
    required this.onDone,
  });

  /// Null unless a point is selected and the shape can lose one.
  final VoidCallback? onDeletePoint;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.polyline_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Przeciągnij punkt lub stuknij środek odcinka',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: 'Usuń punkt',
              onPressed: onDeletePoint,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: 'Anuluj zmiany',
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
            FilledButton(onPressed: onDone, child: const Text('Gotowe')),
          ],
        ),
      ),
    );
  }
}

class _DrawBanner extends StatelessWidget {
  const _DrawBanner({
    required this.kind,
    required this.points,
    required this.onUndo,
    required this.onCancel,
    required this.onDone,
  });

  final ShapeKind kind;
  final int points;
  final VoidCallback? onUndo;
  final VoidCallback onCancel;

  /// Null until there are enough points.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final what = kind == ShapeKind.route ? 'Trasa' : 'Obszar';
    final hint = points < kind.minPoints
        ? 'stuknij, aby dodać punkty (min. ${kind.minPoints})'
        : '$points ${pluralPl(points, 'punkt', 'punkty', 'punktów')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(
              kind == ShapeKind.route
                  ? Icons.timeline
                  : Icons.pentagon_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('$what: $hint')),
            IconButton(
              tooltip: 'Cofnij punkt',
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Anuluj rysowanie',
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
            FilledButton(onPressed: onDone, child: const Text('Gotowe')),
          ],
        ),
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
    required this.onDraw,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  /// Starts drawing a route or area; null while that's not possible.
  final ValueChanged<ShapeKind>? onDraw;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<ShapeKind>(
            tooltip: 'Rysuj',
            enabled: onDraw != null,
            onSelected: onDraw,
            icon: const Icon(Icons.draw_outlined),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ShapeKind.route,
                child: ListTile(
                  leading: Icon(Icons.timeline),
                  title: Text('Trasa'),
                ),
              ),
              PopupMenuItem(
                value: ShapeKind.area,
                child: ListTile(
                  leading: Icon(Icons.pentagon_outlined),
                  title: Text('Obszar'),
                ),
              ),
            ],
          ),
          const Divider(height: 1, indent: 8, endIndent: 8),
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

enum _MapAction { rename, saveImage, settings }
