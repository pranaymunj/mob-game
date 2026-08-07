// battery_usage_test.dart — The drain arithmetic behind the run summary.
//
// This is measurement code, so a wrong number here is worse than no number:
// it would be believed. These pin the cases that quietly corrupt an average —
// a battery that ticks up, a phone on charge, and a run too short for the
// reading to have moved.

import 'package:claimr/services/battery_service.dart';
import 'package:flutter_test/flutter_test.dart';

BatteryUsage usage({
  int start = 80,
  int end = 74,
  Duration duration = const Duration(minutes: 40),
  double distance = 3000,
  bool charging = false,
}) =>
    BatteryUsage(
      startPercent: start,
      endPercent: end,
      duration: duration,
      distanceMeters: distance,
      chargedDuringRun: charging,
    );

void main() {
  test('reports drain, per-hour and per-km for a normal run', () {
    final u = usage(); // 6% over 40 minutes and 3 km
    expect(u.drainPercent, 6);
    expect(u.percentPerHour, closeTo(9.0, 0.01)); // 6% / (2/3)h
    expect(u.percentPerKm, closeTo(2.0, 0.01)); // 6% / 3km
  });

  // iOS reports whole percents and the level can rise a point mid-walk from
  // temperature alone. Left unclamped this is a negative drain, which drags
  // any average built from these readings below the truth.
  test('a battery that ticks up reports zero drain, never negative', () {
    final u = usage(start: 70, end: 72);
    expect(u.drainPercent, 0);
    expect(u.percentPerHour, 0);
  });

  test('a run on charge reports nothing rather than a flattering zero', () {
    final u = usage(charging: true);
    expect(u.percentPerHour, isNull);
    expect(u.percentPerKm, isNull);
    expect(u.isMeaningful, isFalse);
  });

  // Over a few seconds, whole-percent quantisation swamps the signal: a single
  // point of drop reads as a catastrophic hundreds-of-percent-per-hour rate.
  test('a run too short to measure reports nothing', () {
    final u = usage(duration: const Duration(seconds: 20));
    expect(u.percentPerHour, isNull);
    expect(u.isMeaningful, isFalse);
  });

  test('a run too short in distance still reports a per-hour rate', () {
    final u = usage(distance: 10); // paced on the spot for 40 minutes
    expect(u.percentPerKm, isNull);
    expect(u.percentPerHour, closeTo(9.0, 0.01));
    expect(u.isMeaningful, isTrue);
  });

  test('event props carry the figures the analysis needs', () {
    final props = usage().toEventProps();
    expect(props['battery_drain_pct'], 6);
    expect(props['battery_pct_per_hour'], '9.0');
    expect(props['battery_pct_per_km'], '2.0');
    expect(props['battery_charging'], isFalse);
  });
}
