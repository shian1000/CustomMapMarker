import 'package:custom_map_marker/core/measure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2000×1000 px image: normalized x spans twice as many pixels as y.
  const measure = MapMeasure(widthPx: 2000, heightPx: 1000);
  const scaled = MapMeasure(widthPx: 2000, heightPx: 1000, metersPerPixel: 50);

  test('measures lengths in image pixels, respecting the aspect ratio', () {
    expect(measure.lengthPx(const [Offset(0, 0), Offset(0.5, 0)]), 1000);
    expect(measure.lengthPx(const [Offset(0, 0), Offset(0, 0.5)]), 500);
    expect(
      measure.lengthPx(const [Offset(0, 0), Offset(0.3, 0), Offset(0.3, 0.4)]),
      closeTo(600 + 400, 1e-9),
    );
  });

  test('closes the outline for a perimeter', () {
    const square = [
      Offset(0, 0),
      Offset(0.1, 0),
      Offset(0.1, 0.2),
      Offset(0, 0.2),
    ];
    // 200 px sides.
    expect(measure.lengthPx(square), 600);
    expect(measure.lengthPx(square, closed: true), 800);
  });

  test('measures areas in square pixels', () {
    const square = [
      Offset(0, 0),
      Offset(0.1, 0),
      Offset(0.1, 0.2),
      Offset(0, 0.2),
    ];
    expect(measure.areaPx(square), closeTo(40000, 1e-6));
    // Winding direction doesn't matter.
    expect(measure.areaPx(square.reversed.toList()), closeTo(40000, 1e-6));
  });

  test('converts to meters only with a scale', () {
    const line = [Offset(0, 0), Offset(0.5, 0)];
    expect(measure.lengthMeters(line), isNull);
    expect(scaled.lengthMeters(line), 50000);
    expect(
      scaled.areaSquareMeters(const [
        Offset(0, 0),
        Offset(0.1, 0),
        Offset(0.1, 0.2),
        Offset(0, 0.2),
      ]),
      closeTo(40000 * 2500, 1e-3),
    );
  });

  test('formats distances the Polish way', () {
    expect(formatDistance(340), '340 m');
    expect(formatDistance(4200), '4,2 km');
    expect(formatDistance(4000), '4 km');
    expect(formatDistance(12500000), '12 500 km');
    expect(formatPixels(1240), '1 240 px');
  });

  test('formats areas in m², ha or km²', () {
    expect(formatArea(850), '850 m²');
    expect(formatArea(34000), '3,4 ha');
    expect(formatArea(250000), '25 ha');
    expect(formatArea(3400000), '3,4 km²');
    expect(formatArea(12500000000), '12 500 km²');
  });

  test('picks round scale bar lengths', () {
    expect(niceScaleLength(87), 50);
    expect(niceScaleLength(230), 200);
    expect(niceScaleLength(1000), 1000);
    expect(niceScaleLength(19999), 10000);
  });
}
