import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Draggable handles on a route's or area's points while editing them, plus
/// smaller handles in the middle of each segment that insert a point.
///
/// Dragging a handle moves its point instead of panning the map (see
/// [_HandleTouch]). Tapping one selects the point, or inserts one at a
/// segment's middle.
class ShapePointHandles extends StatelessWidget {
  const ShapePointHandles({
    super.key,
    required this.points,
    required this.closed,
    required this.color,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onMoveEnd,
    required this.onInsert,
  });

  final List<LatLng> points;

  /// Areas also have a segment from the last point back to the first.
  final bool closed;
  final Color color;
  final int? selected;
  final ValueChanged<int> onSelect;

  /// The point at [index] dragged to [to] (map coordinates).
  final void Function(int index, LatLng to) onMove;

  /// Dragging the point at [index] ended at [screenPosition] (relative to the
  /// map), e.g. to snap it to a marker.
  final void Function(int index, Offset screenPosition) onMoveEnd;

  /// Inserts a point at [index] (between index-1 and index) at [at].
  final void Function(int index, LatLng at) onInsert;

  static const double _vertexSize = 22;
  static const double _midpointSize = 16;

  /// Touch target around each handle, larger than what's drawn.
  static const double _touchSize = 44;

  /// Segments shorter than this on screen get no midpoint handle.
  static const double _minSegmentForMidpoint = _touchSize * 2;

  static double _screenLength(MapCamera camera, LatLng a, LatLng b) =>
      (camera.latLngToScreenOffset(a) - camera.latLngToScreenOffset(b))
          .distance;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    // This layer covers the map exactly (no rotation in this app), so its
    // box converts global touch positions to map-relative ones.
    Offset toMap(Offset global) =>
        (context.findRenderObject()! as RenderBox).globalToLocal(global);
    LatLng toLatLng(Offset global) =>
        camera.screenOffsetToLatLng(toMap(global));

    final segments = closed ? points.length : points.length - 1;
    return MarkerLayer(
      markers: [
        for (var i = 0; i < segments; i++)
          // On short segments a midpoint handle would sit on top of the
          // points' handles; zooming in brings it back.
          if (_screenLength(
                camera,
                points[i],
                points[(i + 1) % points.length],
              ) >=
              _minSegmentForMidpoint)
            _handle(
              key: 'mid-$i',
              point: _midpoint(points[i], points[(i + 1) % points.length]),
              child: _dot(_midpointSize, filled: false, faded: true),
              onTap: () => onInsert(
                i + 1,
                _midpoint(points[i], points[(i + 1) % points.length]),
              ),
              // Dragging a midpoint inserts a point there and drags it.
              onDragStart: () => onInsert(
                i + 1,
                _midpoint(points[i], points[(i + 1) % points.length]),
              ),
              onDrag: (global) => onMove(i + 1, toLatLng(global)),
              onDragEnd: (global) => onMoveEnd(i + 1, toMap(global)),
            ),
        for (final (i, p) in points.indexed)
          _handle(
            key: 'vertex-$i',
            point: p,
            child: _dot(_vertexSize, filled: i == selected),
            onTap: () => onSelect(i),
            onDragStart: () {},
            onDrag: (global) => onMove(i, toLatLng(global)),
            onDragEnd: (global) => onMoveEnd(i, toMap(global)),
          ),
      ],
    );
  }

  Marker _handle({
    required String key,
    required LatLng point,
    required Widget child,
    required VoidCallback onTap,
    required VoidCallback onDragStart,
    required ValueChanged<Offset> onDrag,
    required ValueChanged<Offset> onDragEnd,
  }) => Marker(
    key: ValueKey(key),
    point: point,
    width: _touchSize,
    height: _touchSize,
    child: _HandleTouch(
      onTap: onTap,
      onDragStart: onDragStart,
      onDrag: onDrag,
      onDragEnd: onDragEnd,
      child: Center(child: child),
    ),
  );

  Widget _dot(double size, {required bool filled, bool faded = false}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled
              ? color
              : Colors.white.withValues(alpha: faded ? 0.7 : 1),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: faded ? 0.7 : 1),
            width: 3,
          ),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black38)],
        ),
      );

  static LatLng _midpoint(LatLng a, LatLng b) =>
      LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
}

/// Owns every touch that starts on a handle.
///
/// The eager recognizer wins the gesture arena on touch down, so the map's
/// drag recognizers never get the gesture. (A regular drag recognizer only
/// competes once the finger has moved, and on a phone the map's could win.)
/// Movement and taps are then read from the raw pointer events.
class _HandleTouch extends StatefulWidget {
  const _HandleTouch({
    required this.onTap,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required this.child,
  });

  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDrag;
  final ValueChanged<Offset> onDragEnd;
  final Widget child;

  @override
  State<_HandleTouch> createState() => _HandleTouchState();
}

class _HandleTouchState extends State<_HandleTouch> {
  int? _pointer;
  Offset _start = Offset.zero;
  bool _dragging = false;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _start = e.position;
    _dragging = false;
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (!_dragging && (e.position - _start).distance > kTouchSlop / 2) {
      _dragging = true;
      widget.onDragStart();
    }
    if (_dragging) widget.onDrag(e.position);
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_dragging) {
      widget.onDragEnd(e.position);
    } else {
      widget.onTap();
    }
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    // A gesture taken away (e.g. by the system) is never a tap.
    if (_dragging) widget.onDragEnd(e.position);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _cancel,
    child: RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: widget.child,
    ),
  );
}
