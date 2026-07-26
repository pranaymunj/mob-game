// gps_noise_test.dart — Guards the fix for the bug where simply holding or
// waving a stationary phone accumulated "distance" from GPS drift.

import 'dart:async';

import 'package:claimr/core/providers.dart';
import 'package:claimr/features/run/run_controller.dart';
import 'package:claimr/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Emits whatever samples the test supplies.
class FakeLocationService implements LocationService {
  final List<GpsSample> samples;
  FakeLocationService(this.samples);

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<GpsSample?> current() async => samples.first;

  @override
  Stream<GpsSample> positions() => Stream.fromIterable(samples);
}

// A point offset from a base by roughly [metres] east — enough for our scale.
double lngOffset(double baseLng, double metres) => baseLng + metres / 88000.0;

void main() {
  const baseLng = -122.4194;
  const baseLat = 37.7749;
  final t0 = DateTime(2026, 1, 1, 12);

  Future<double> runWith(List<GpsSample> samples) async {
    final container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(FakeLocationService(samples)),
      backendEnabledProvider.overrideWithValue(false), // no network in tests
    ]);
    addTearDown(container.dispose);

    final controller = container.read(runControllerProvider.notifier);
    await controller.start();
    // Let the stream drain.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return container.read(runControllerProvider).sessionDistanceM;
  }

  test('a stationary phone with GPS jitter accumulates no distance', () async {
    // Sitting still: the OS reports ~0 speed while the position wobbles by
    // 10-25m. This is exactly the "swinging the phone" case.
    final jitter = <GpsSample>[];
    const wobbles = [0.0, 12.0, -18.0, 9.0, 22.0, -14.0, 6.0];
    for (var i = 0; i < wobbles.length; i++) {
      jitter.add(GpsSample(
        lng: lngOffset(baseLng, wobbles[i]),
        lat: baseLat,
        speedMps: 0.1, // OS says: not walking
        accuracy: 12,
        at: t0.add(Duration(seconds: i * 3)),
      ));
    }

    expect(await runWith(jitter), 0.0);
  });

  test('a low-accuracy fix is rejected even if it looks like movement',
      () async {
    final badFixes = [
      GpsSample(
          lng: baseLng,
          lat: baseLat,
          speedMps: 1.3,
          accuracy: 60, // way past the accuracy gate
          at: t0),
      GpsSample(
          lng: lngOffset(baseLng, 40),
          lat: baseLat,
          speedMps: 1.3,
          accuracy: 60,
          at: t0.add(const Duration(seconds: 5))),
    ];

    expect(await runWith(badFixes), 0.0);
  });

  test('unknown speed (-1, iOS when stationary) stays near zero', () async {
    // Sitting on a chair: iOS can't determine speed so it reports -1, while the
    // position drifts ±25m per fix. The Kalman filter damps this hard; a little
    // residual can leak (speed can't be used to reject it), but it must stay
    // far below the raw drift — not accumulate a phantom walk.
    final drift = <GpsSample>[];
    const wobbles = [0.0, 16.0, -20.0, 18.0, 25.0];
    for (var i = 0; i < wobbles.length; i++) {
      drift.add(GpsSample(
        lng: lngOffset(baseLng, wobbles[i]),
        lat: baseLat,
        speedMps: -1, // "unknown"
        accuracy: 10,
        at: t0.add(Duration(seconds: i * 5)),
      ));
    }

    // Raw drift totals ~80m of jitter; smoothed must be a small fraction.
    expect(await runWith(drift), lessThan(20));
  });

  test('the initial coarse-fix snap does not count as travel', () async {
    // Phones return a cached/approximate location, then snap to the true one.
    // That jump must not register as an instant sprint.
    final snap = [
      GpsSample( // coarse first fix
          lng: lngOffset(baseLng, 0),
          lat: baseLat,
          speedMps: 1.3,
          accuracy: 18,
          at: t0),
      GpsSample( // snaps 30m to the real position
          lng: lngOffset(baseLng, 30),
          lat: baseLat,
          speedMps: 1.3,
          accuracy: 6,
          at: t0.add(const Duration(seconds: 2))),
      GpsSample( // settled, still not really moving far
          lng: lngOffset(baseLng, 32),
          lat: baseLat,
          speedMps: 1.3,
          accuracy: 6,
          at: t0.add(const Duration(seconds: 5))),
    ];

    expect(await runWith(snap), 0.0);
  });

  test('dense-urban walking counts (real readings: ±13m, 0.3m/s, 4m steps)',
      () async {
    // Captured from an actual walk in a built-up area: iOS under-reports speed
    // (0.3 m/s) and accuracy is mediocre (±13m), with a fix every ~4m. This
    // combination previously produced 0m forever.
    final urbanWalk = <GpsSample>[];
    for (var i = 0; i < 20; i++) {
      urbanWalk.add(GpsSample(
        lng: lngOffset(baseLng, i * 4.0), // 4m per fix
        lat: baseLat,
        speedMps: 0.3, // degraded urban speed estimate
        accuracy: 13,
        at: t0.add(Duration(seconds: i * 3)),
      ));
    }

    final distance = await runWith(urbanWalk);
    // ~72m of real walking after warm-up; must register a solid chunk of it.
    expect(distance, greaterThan(40));
  });

  test('genuine walking still accumulates distance', () async {
    // ~1.3 m/s with good accuracy, moving 20m every 15s (past warm-up).
    final walk = <GpsSample>[];
    for (var i = 0; i < 8; i++) {
      walk.add(GpsSample(
        lng: lngOffset(baseLng, i * 20.0),
        lat: baseLat,
        speedMps: 1.3,
        accuracy: 5,
        at: t0.add(Duration(seconds: i * 15)),
      ));
    }

    final distance = await runWith(walk);
    expect(distance, greaterThan(50));
  });
}
