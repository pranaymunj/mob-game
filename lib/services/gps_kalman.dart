// gps_kalman.dart — 1-D-per-axis constant-position Kalman filter for GPS.
//
// Raw phone GPS jitters several metres even when you're still; that jitter both
// corrupts the trail and inflates distance. This collapses the jitter while
// preserving genuine movement (corners stay sharp). It's the "simple, ship-it-
// first" variant from the TERRA spec §5.3, and it's what real fitness apps use
// under the hood.
//
// Stateful: feed each raw sample through process(); call reset() at run start.

import 'dart:math' as math;

import 'location_service.dart';

class GpsKalman {
  // Process noise (metres/second-ish): how much we expect real motion between
  // fixes. Higher = trusts new readings more (whippier). Tuned for walking.
  final double q;

  double _lat = 0, _lng = 0;
  double _variance = -1; // metres²; <0 means "not initialised"
  DateTime? _lastAt;

  GpsKalman({this.q = 3.0});

  void reset() {
    _variance = -1;
    _lastAt = null;
  }

  /// Returns a smoothed copy of [s] (same speed/accuracy/time, filtered lat/lng).
  GpsSample process(GpsSample s) {
    // Accuracy is the measurement noise. Clamp so a bogus 0 can't divide badly.
    final acc = s.accuracy < 1 ? 1.0 : s.accuracy;

    if (_variance < 0) {
      _lat = s.lat;
      _lng = s.lng;
      _variance = acc * acc;
      _lastAt = s.at;
      return s;
    }

    // Predict: uncertainty grows with time since the last fix.
    final dt =
        (s.at.difference(_lastAt!).inMilliseconds / 1000.0).clamp(0.0, 10.0);
    _lastAt = s.at;
    _variance += dt * q * q;

    // Update: blend prediction with the new measurement by the Kalman gain.
    final k = _variance / (_variance + acc * acc); // 0..1, dimensionless
    _lat += k * (s.lat - _lat);
    _lng += k * (s.lng - _lng);
    _variance = (1 - k) * _variance;

    return GpsSample(
      lng: _lng,
      lat: _lat,
      speedMps: s.speedMps, // OS speed is more reliable than a derived one
      accuracy: s.accuracy,
      at: s.at,
    );
  }

  // Process noise tuned per travel mode (walk steadiest, cycle whippiest).
  static double qFor(String mode) => switch (mode) {
        'run' => 5.0,
        'cycle' => 9.0,
        _ => math.max(3.0, 3.0), // walk
      };
}
