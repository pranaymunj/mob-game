// geometry_service.dart — Loop detection + polygon math (the capture engine).
// Uses the `turf` library for real geometry (distance, area). We never
// hand-roll computational geometry (CLAUDE.md Part 2).
//
// Loop-detection approach (kept simple): as the trail grows, we check whether
// the newest point has come back within `loopCloseMeters` of an EARLIER point
// (skipping the last few, so a stationary GPS jitter doesn't count). If it has,
// the slice from that earlier point to now is a closed ring = your claimed loop.

import 'package:turf/turf.dart';

import '../core/constants.dart';

class GeometryService {
  // Index of the earliest trail point the newest point closes back onto,
  // or null if the trail hasn't formed a loop yet.
  int? loopStartIndex(List<List<double>> trail) {
    // Need enough points to enclose a real area.
    if (trail.length < 6) return null;

    final last = _point(trail.last);
    // Skip the most recent few points: they're always near `last`.
    final searchEnd = trail.length - 4;
    for (var i = 0; i < searchEnd; i++) {
      final meters = distance(_point(trail[i]), last, Unit.meters);
      if (meters <= AppConstants.loopCloseMeters) return i;
    }
    return null;
  }

  // Build the closed polygon ring (a list of [lng, lat]) from the loop portion
  // of the trail. First and last points are equal, as GeoJSON rings require.
  List<List<double>> enclosedPolygon(List<List<double>> trail, int startIndex) {
    final ring = trail.sublist(startIndex).map((p) => [p[0], p[1]]).toList();
    if (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1]) {
      ring.add([ring.first[0], ring.first[1]]);
    }
    return ring;
  }

  // Area of a closed ring in square meters.
  double areaSqMeters(List<List<double>> ring) {
    final polygon = Polygon(coordinates: [
      ring.map((p) => Position(p[0], p[1])).toList(),
    ]);
    return (area(polygon) ?? 0).toDouble();
  }

  // Great-circle distance between two [lng, lat] points, in meters.
  double distanceMeters(List<double> a, List<double> b) =>
      distance(_point(a), _point(b), Unit.meters).toDouble();

  // Total length of a path (sum of segment distances), in meters.
  double perimeterMeters(List<List<double>> ring) {
    var total = 0.0;
    for (var i = 1; i < ring.length; i++) {
      total += distanceMeters(ring[i - 1], ring[i]);
    }
    return total;
  }

  Point _point(List<double> p) => Point(coordinates: Position(p[0], p[1]));
}
