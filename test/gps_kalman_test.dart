// gps_kalman_test.dart — The smoothing filter must kill stationary jitter while
// preserving genuine walking, or it would either count drift as distance or
// erase real movement.

import 'package:claimr/services/gps_kalman.dart';
import 'package:claimr/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _lat0 = 19.12, _lng0 = 72.85;
const _mPerDegLng = 104000.0;

GpsSample at(double eastMetres, DateTime t, {double acc = 12}) => GpsSample(
      lng: _lng0 + eastMetres / _mPerDegLng,
      lat: _lat0,
      speedMps: 1.2,
      accuracy: acc,
      at: t,
    );

double eastMetres(GpsSample s) => (s.lng - _lng0) * _mPerDegLng;

void main() {
  test('collapses jitter around a stationary point', () {
    final k = GpsKalman();
    var t = DateTime(2026, 1, 1, 9);
    // True position 0m; readings wobble ±15m.
    const wobble = <double>[0, 15, -12, 14, -15, 11, -13, 9];
    var maxOut = 0.0;
    for (final w in wobble) {
      final out = k.process(at(w, t));
      maxOut = maxOut < eastMetres(out).abs() ? eastMetres(out).abs() : maxOut;
      t = t.add(const Duration(seconds: 3));
    }
    // Smoothed output should stay far tighter than the ±15m raw wobble.
    expect(maxOut, lessThan(9),
        reason: 'filter should damp the raw ±15m jitter toward the true 0m');
  });

  test('tracks genuine forward walking', () {
    final k = GpsKalman();
    var t = DateTime(2026, 1, 1, 9);
    GpsSample? last;
    for (var i = 0; i <= 20; i++) {
      last = k.process(at(i * 5.0, t, acc: 6)); // walk east 5m per fix
      t = t.add(const Duration(seconds: 3));
    }
    // After 100m of walking, the estimate should be near 100m (not stuck back).
    expect(eastMetres(last!), greaterThan(80),
        reason: 'real sustained movement must not be smoothed away');
  });

  test('reset clears state for a new run', () {
    final k = GpsKalman();
    final t = DateTime(2026, 1, 1, 9);
    k.process(at(500, t)); // far-away first fix
    k.reset();
    final out = k.process(at(0, t)); // new run starts at 0m
    expect(eastMetres(out).abs(), lessThan(1),
        reason: 'after reset the first fix is taken as-is');
  });
}
