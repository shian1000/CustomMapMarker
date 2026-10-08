import 'dart:ui';

import 'package:custom_map_marker/core/coordinate_mapper.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('MapCoordinateMapper', () {
    final landscape = MapCoordinateMapper(widthPx: 4000, heightPx: 2000);
    final portrait = MapCoordinateMapper(widthPx: 1000, heightPx: 3000);

    test('keeps every corner inside valid lat/lng ranges', () {
      for (final m in [landscape, portrait]) {
        for (final c in const [
          Offset(0, 0),
          Offset(1, 0),
          Offset(0, 1),
          Offset(1, 1),
        ]) {
          final p = m.toLatLng(c);
          expect(p.latitude, inInclusiveRange(-90, 90));
          expect(p.longitude, inInclusiveRange(-180, 180));
        }
      }
    });

    test('preserves aspect ratio', () {
      final b = landscape.bounds;
      final w = b.east - b.west;
      final h = b.north - b.south;
      expect(w / h, closeTo(2, 1e-9));
    });

    test('round-trips normalized positions', () {
      for (final m in [landscape, portrait]) {
        for (final n in const [Offset(0.25, 0.75), Offset(0.9, 0.1)]) {
          final back = m.toNormalized(m.toLatLng(n));
          expect(back.dx, closeTo(n.dx, 1e-9));
          expect(back.dy, closeTo(n.dy, 1e-9));
        }
      }
    });

    test('top-left of image is north-west', () {
      final tl = landscape.toLatLng(Offset.zero);
      final br = landscape.toLatLng(const Offset(1, 1));
      expect(tl.latitude, greaterThan(br.latitude));
      expect(tl.longitude, lessThan(br.longitude));
    });

    test('contains only points on the image', () {
      expect(
        landscape.contains(landscape.toLatLng(const Offset(0.5, 0.5))),
        isTrue,
      );
      expect(landscape.contains(const LatLng(-80, 10)), isFalse);
    });

    test('native zoom maps one image pixel to one screen pixel', () {
      for (final m in [landscape, portrait]) {
        final b = m.bounds;
        final screenPxPerUnit = const CrsSimple().scale(m.nativeZoom);
        expect((b.east - b.west) * screenPxPerUnit, closeTo(m.widthPx, 1e-6));
        expect(
          (b.north - b.south) * screenPxPerUnit,
          closeTo(m.heightPx, 1e-6),
        );
      }
    });

    test('native zoom is the integer top level of the tile pyramid', () {
      // 4000 px: 256 * 2^4 = 4096 is the first level that fits.
      expect(landscape.nativeZoom, closeTo(4, 1e-9));
      // 3000 px: 256 * 2^4 = 4096 as well.
      expect(portrait.nativeZoom, closeTo(4, 1e-9));
      expect(
        MapCoordinateMapper(widthPx: 100, heightPx: 50).nativeZoom,
        closeTo(0, 1e-9),
      );
    });

    test('fit zoom is native zoom when viewport equals image size', () {
      expect(
        landscape.fitZoom(const Size(4000, 2000)),
        closeTo(landscape.nativeZoom, 1e-9),
      );
      expect(
        landscape.fitZoom(const Size(2000, 2000)),
        closeTo(landscape.nativeZoom - 1, 1e-9),
      );
    });
  });
}
