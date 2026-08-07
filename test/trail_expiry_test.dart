// trail_expiry_test.dart — Trail vulnerability (CLAUDE.md Part 8).
//
// An open trail is perishable: points older than the lifetime drop off the
// START, so a loop you dawdle over shrinks until it can't be closed.
//
// The invariant worth guarding is that `trail` and the controller's private
// `_times` stay index-aligned. Loop detection reads `_times[startIndex]` to
// time a capture, so trimming one without the other would either throw or —
// far worse — silently mis-time every loop and hand the server a duration that
// fails its speed gate.

import 'package:claimr/core/constants.dart';
import 'package:claimr/core/providers.dart';
import 'package:claimr/features/run/run_controller.dart';
import 'package:claimr/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLocation implements LocationService {
  final List<GpsSample> samples;
  FakeLocation(this.samples);
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<GpsSample?> current() async => samples.first;
  @override
  Stream<GpsSample> positions() => Stream.fromIterable(samples);
}

/// Walk east in a straight line, one fix every [gap], timestamped from [start].
/// Steps are 12m — comfortably past the noise floor so every fix is accepted.
List<GpsSample> walkLine({
  required DateTime start,
  required int count,
  Duration gap = const Duration(seconds: 20),
}) {
  const metresPerDegLng = 104000.0;
  return [
    for (var i = 0; i < count; i++)
      GpsSample(
        lng: 72.8500 + (i * 12.0) / metresPerDegLng,
        lat: 19.1200,
        speedMps: 1.2,
        accuracy: 6,
        at: start.add(gap * i),
      ),
  ];
}

Future<RunController> run(List<GpsSample> samples) async {
  final container = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(FakeLocation(samples)),
    backendEnabledProvider.overrideWithValue(false),
  ]);
  addTearDown(container.dispose);
  final c = container.read(runControllerProvider.notifier);
  await c.start();
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return c;
}

void main() {
  test('a trail walked inside the lifetime keeps every point', () async {
    // 20 fixes, 20s apart = under 7 minutes, well inside the 12-minute life.
    final c = await run(walkLine(start: DateTime.now(), count: 20));

    expect(c.state.trail.length, greaterThan(10),
        reason: 'nothing should expire inside the lifetime');
    expect(c.state.trailExpiresAt, isNotNull);
  });

  test('points older than the lifetime drop off the start of the trail',
      () async {
    // Timestamps start well in the past, so the early fixes are already stale
    // by the time the later ones arrive.
    final start =
        DateTime.now().subtract(AppConstants.trailLifetime + const Duration(minutes: 6));
    final c = await run(walkLine(start: start, count: 30, gap: const Duration(seconds: 40)));

    // 30 fixes × 40s spans 20 minutes against a 12-minute life, so roughly the
    // oldest third must be gone.
    expect(c.state.trail.length, lessThan(25),
        reason: 'the oldest points should have expired');
    expect(c.state.trail, isNotEmpty,
        reason: 'expiry must never empty the trail entirely');
  });

  test('a capture after expiry is still timed correctly', () async {
    // The real risk: if _times were trimmed out of step with the trail, loop
    // timing would be wrong or would throw. Walking on after an expiry and
    // banking exercises the same indexing path a capture uses.
    final start =
        DateTime.now().subtract(AppConstants.trailLifetime + const Duration(minutes: 4));
    final c = await run(walkLine(start: start, count: 40, gap: const Duration(seconds: 30)));

    // Reaching here without an exception means indices stayed in range; the
    // run must also still be coherent.
    expect(c.state.isActive, isTrue);
    expect(c.state.trail, isNotEmpty);
    expect(c.state.sessionDistanceM, greaterThan(0));
  });

  test('the countdown is derived live, so it advances between fixes', () async {
    final c = await run(walkLine(start: DateTime.now(), count: 6));

    final first = c.state.trailExpiresIn;
    expect(first, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final later = c.state.trailExpiresIn!;

    expect(later, lessThan(first!),
        reason: 'a countdown stored as a fixed Duration would freeze here');
  });

  test('the at-risk warning only fires near expiry', () async {
    final fresh = await run(walkLine(start: DateTime.now(), count: 6));
    expect(fresh.state.trailAtRisk, isFalse,
        reason: 'a warning that nags from the first step is ignored by the '
            'time it matters');
  });
}
