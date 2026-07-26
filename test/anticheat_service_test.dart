// anticheat_service_test.dart — Verifies speed caps and vehicle detection.

import 'package:flutter_test/flutter_test.dart';
import 'package:claimr/services/anticheat_service.dart';
import 'package:claimr/models/run.dart';

void main() {
  final ac = AntiCheatService();

  test('walking speed is within the walk cap', () {
    expect(ac.speedWithinCap(1.4, RunMode.walk), isTrue); // ~5 km/h
  });

  test('sprinting is over the walk cap', () {
    expect(ac.speedWithinCap(6.0, RunMode.walk), isFalse); // ~21 km/h
  });

  test('running speed is within the run cap but the walk cap rejects it', () {
    expect(ac.speedWithinCap(5.5, RunMode.run), isTrue);
    expect(ac.speedWithinCap(5.5, RunMode.walk), isFalse);
  });

  test('car-like speed implies a vehicle (auto-pause)', () {
    expect(ac.impliesVehicle(20), isTrue); // ~72 km/h
    expect(ac.impliesVehicle(1.4), isFalse);
  });
}
