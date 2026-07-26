// geometry_service_test.dart — Verifies loop detection + area on a walked square.

import 'package:flutter_test/flutter_test.dart';
import 'package:claimr/services/geometry_service.dart';

void main() {
  final geo = GeometryService();

  test('does not detect a loop on an open trail', () {
    final open = [
      [-122.4194, 37.7749],
      [-122.4190, 37.7749],
      [-122.4190, 37.7752],
    ];
    expect(geo.loopStartIndex(open), isNull);
  });

  test('detects a loop when the trail returns near an earlier point', () {
    // A ~35m square, ending ~1-2m from the start point.
    final square = [
      [-122.4194, 37.7749], // 0 (start)
      [-122.4190, 37.7749], // 1
      [-122.4190, 37.7752], // 2
      [-122.4194, 37.7752], // 3
      [-122.4194, 37.7750], // 4 (heading back)
      [-122.41941, 37.77491], // 5 (~2m from start)
    ];

    final startIndex = geo.loopStartIndex(square);
    expect(startIndex, 0);

    final ring = geo.enclosedPolygon(square, startIndex!);
    // Ring must be closed (first == last).
    expect(ring.first, ring.last);

    final area = geo.areaSqMeters(ring);
    // Roughly a 35m x 33m block -> ~1000-1300 m².
    expect(area, greaterThan(500));
    expect(area, lessThan(3000));
  });
}
