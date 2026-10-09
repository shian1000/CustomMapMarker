import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/clustering.dart';
import '../../data/map_marker.dart';
import '../../shared/marker_colors.dart';
import '../../shared/widgets/marker_pin.dart';

/// Draws markers, merging those that would overlap on screen into a counted
/// circle. Must be a child of a FlutterMap: it re-clusters as the zoom level
/// changes.
class ClusteredMarkerLayer extends StatelessWidget {
  const ClusteredMarkerLayer({
    super.key,
    required this.markers,
    required this.positionOf,
    required this.pinBuilder,
    required this.onClusterTap,
    required this.clusterBelowZoom,
    this.neverCluster = const {},
  });

  final List<MapMarker> markers;
  final LatLng Function(MapMarker marker) positionOf;
  final Widget Function(MapMarker marker) pinBuilder;
  final void Function(List<MapMarker> members) onClusterTap;

  /// From this zoom on (e.g. full image resolution) every marker is drawn
  /// on its own, so even markers on the same spot can be reached.
  final double clusterBelowZoom;

  /// Ids drawn on their own regardless, e.g. the marker being moved.
  final Set<String> neverCluster;

  /// Pins closer than this on screen would overlap: labels are up to
  /// [MarkerPin.width] wide, the pin with its label [MarkerPin.height] tall.
  static const double _maxDx = MarkerPin.width * 0.6;
  static const double _maxDy = MarkerPin.height * 0.8;

  static const double _clusterSize = 44;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    // Cluster at a whole zoom level, in world coordinates: panning then never
    // regroups markers, only crossing a zoom level does.
    final zoom = camera.zoom.floorToDouble();
    final clustering = camera.zoom < clusterBelowZoom;
    final clusters = clustering
        ? clusterByDistance(
            [
              for (final m in markers)
                if (!neverCluster.contains(m.id)) m,
            ],
            (m) => camera.projectAtZoom(positionOf(m), zoom),
            maxDx: _maxDx,
            maxDy: _maxDy,
          )
        : null;

    return MarkerLayer(
      alignment: Alignment.topCenter,
      markers: [
        if (clusters == null)
          for (final m in markers) _pin(m)
        else ...[
          for (final cluster in clusters)
            if (cluster.isSingle)
              _pin(cluster.members.single)
            else
              _cluster(cluster, camera.unprojectAtZoom(cluster.center, zoom)),
          for (final m in markers)
            if (neverCluster.contains(m.id)) _pin(m),
        ],
      ],
    );
  }

  Marker _pin(MapMarker m) => Marker(
    key: ValueKey(m.id),
    point: positionOf(m),
    width: MarkerPin.width,
    height: MarkerPin.height,
    child: pinBuilder(m),
  );

  Marker _cluster(Cluster<MapMarker> cluster, LatLng point) {
    final members = cluster.members;
    final colors = {for (final m in members) m.colorValue};
    return Marker(
      // Stable per membership, so Flutter doesn't mix up neighbouring groups.
      key: ValueKey('cluster:${members.map((m) => m.id).join(',')}'),
      point: point,
      width: _clusterSize,
      height: _clusterSize,
      alignment: Alignment.center,
      child: MarkerClusterBadge(
        count: members.length,
        color: colors.length == 1 ? Color(colors.single) : null,
        onTap: () => onClusterTap(members),
      ),
    );
  }
}

/// A circle with the number of markers it stands for.
class MarkerClusterBadge extends StatelessWidget {
  const MarkerClusterBadge({
    super.key,
    required this.count,
    this.color,
    this.onTap,
  });

  final int count;

  /// The members' shared color, or null if they differ.
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? Theme.of(context).colorScheme.inverseSurface;
    return Semantics(
      button: true,
      label: '$count znaczników – przybliż',
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
          ),
          child: Center(
            child: Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(
                color: onColor(fill),
                fontWeight: FontWeight.bold,
                fontSize: count > 99 ? 12 : 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
