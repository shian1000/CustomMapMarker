import 'package:flutter/foundation.dart';

/// Name and filter state of one marker color on one map.
@immutable
class LegendEntry {
  const LegendEntry({this.name, this.hidden = false});

  final String? name;
  final bool hidden;
}

/// Legend of one map: entries keyed by ARGB color value. Colors missing from
/// it are unnamed and shown.
typedef MapLegend = Map<int, LegendEntry>;

extension LegendLookup on MapLegend {
  String? nameOf(int colorValue) => this[colorValue]?.name;

  bool isHidden(int colorValue) => this[colorValue]?.hidden ?? false;

  bool get hasHidden => values.any((e) => e.hidden);

  /// Names only, for showing next to colors.
  Map<int, String> get names => {
    for (final MapEntry(:key, :value) in entries) key: ?value.name,
  };
}
