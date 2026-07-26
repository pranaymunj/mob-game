// first_run_guide_test.dart — The guided first capture has to advance through
// its steps in the right order, and the suggested loop has to be a real,
// walkable square of roughly the right size.

import 'package:claimr/features/run/first_run_guide.dart';
import 'package:claimr/services/geometry_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lng = 72.85, lat = 19.12; // the latitude the field data came from

  group('suggested loop', () {
    final ring = FirstRunGuide.suggestedLoop(lng: lng, lat: lat);

    test('is a closed square', () {
      expect(ring.length, 5);
      expect(ring.first, ring.last, reason: 'ring must be closed');
    });

    test('encloses roughly the intended area', () {
      final area = GeometryService().areaSqMeters(ring);
      // 60m sides -> ~3600 m². Allow for projection slop.
      expect(area, greaterThan(3000));
      expect(area, lessThan(4300));
    });

    test('sides are long enough to beat GPS noise', () {
      final g = GeometryService();
      final side = g.distanceMeters(ring[0], ring[1]);
      // Must comfortably exceed the ~13m accuracy seen in built-up areas.
      expect(side, greaterThan(50));
      expect(side, lessThan(70));
    });
  });

  group('coaching steps', () {
    test('starts by pointing at the guide', () {
      final s = FirstRunGuide.coach(
          trailPoints: 0, metersToClose: null, distanceWalked: 0);
      expect(s.title, contains('dotted square'));
    });

    test('acknowledges progress once walking', () {
      final s = FirstRunGuide.coach(
          trailPoints: 2, metersToClose: null, distanceWalked: 30);
      expect(s.title, contains('trail'));
    });

    test('tells you to loop back when far from the start', () {
      final s = FirstRunGuide.coach(
          trailPoints: 12, metersToClose: 90, distanceWalked: 150);
      expect(s.title, contains('loop back'));
      expect(s.body, contains('90'));
    });

    test('switches to closing when nearly home', () {
      final s = FirstRunGuide.coach(
          trailPoints: 20, metersToClose: 15, distanceWalked: 220);
      expect(s.title, contains('Close the loop'));
    });
  });
}
