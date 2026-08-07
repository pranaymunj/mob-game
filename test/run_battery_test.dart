// run_battery_test.dart — Proves the battery reading actually travels from the
// service, through the run controller, into the state the summary screen reads.
//
// The arithmetic is covered in battery_usage_test; what this pins is the
// wiring, which is the part that silently does nothing. It also pins the
// degrade path: a device that won't report its battery must produce a run with
// no reading, not a broken run.

import 'package:claimr/core/providers.dart';
import 'package:claimr/features/run/run_controller.dart';
import 'package:claimr/services/battery_service.dart';
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

/// Reports a scripted pair of levels: the first read is the run's start, the
/// second its end.
class ScriptedBattery implements BatteryService {
  final List<int?> levels;
  final bool charging;
  int _i = 0;
  ScriptedBattery(this.levels, {this.charging = false});

  @override
  Future<int?> level() async =>
      _i < levels.length ? levels[_i++] : levels.last;

  @override
  Future<bool> isCharging() async => charging;
}

/// A device that simply won't say — simulators, and some Android OEMs.
class SilentBattery implements BatteryService {
  @override
  Future<int?> level() async => null;
  @override
  Future<bool> isCharging() async => false;
}

/// Answers slowly, so a new run can start while the reading is still in flight.
class SlowBattery implements BatteryService {
  final List<int?> levels;
  final Duration delay;
  int _i = 0;
  SlowBattery(this.levels, {this.delay = const Duration(milliseconds: 150)});

  @override
  Future<int?> level() async {
    await Future<void>.delayed(delay);
    return _i < levels.length ? levels[_i++] : levels.last;
  }

  @override
  Future<bool> isCharging() async => false;
}

List<GpsSample> _walk() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 12; i++)
      GpsSample(
        lng: 72.85 + i * 0.00004,
        lat: 19.12,
        speedMps: 1.2,
        accuracy: 8,
        at: now.add(Duration(seconds: i * 4)),
      ),
  ];
}

Future<RunController> walkWith(BatteryService battery) async {
  final container = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(FakeLocation(_walk())),
    batteryServiceProvider.overrideWithValue(battery),
    backendEnabledProvider.overrideWithValue(false),
  ]);
  addTearDown(container.dispose);
  final c = container.read(runControllerProvider.notifier);
  await c.start();
  await Future<void>.delayed(const Duration(milliseconds: 100));
  c.stop();
  // stop() reports the battery off the critical path, so let it land.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return c;
}

void main() {
  test('a run records the battery it started and ended on', () async {
    final c = await walkWith(ScriptedBattery([80, 74]));
    final usage = c.state.battery;

    expect(usage, isNotNull, reason: 'the reading should reach run state');
    expect(usage!.startPercent, 80);
    expect(usage.endPercent, 74);
    expect(usage.drainPercent, 6);
  });

  test('a device that will not report its battery still completes the run',
      () async {
    final c = await walkWith(SilentBattery());
    expect(c.state.battery, isNull);
    expect(c.state.isActive, isFalse, reason: 'the run itself must still end');
  });

  test('a run on charge is marked unmeasurable rather than reported as 0%',
      () async {
    final c = await walkWith(ScriptedBattery([80, 80], charging: true));
    final usage = c.state.battery;

    expect(usage, isNotNull);
    expect(usage!.chargedDuringRun, isTrue);
    expect(usage.isMeaningful, isFalse);
  });

  // The battery read is slow enough that a player can tap Start again before
  // it lands. If the late reading were applied anyway, the finished run's
  // drain would appear on the new run's summary — a wrong number with nothing
  // to reveal that it was wrong.
  test('a reading that lands after a new run has started is discarded',
      () async {
    final container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(FakeLocation(_walk())),
      batteryServiceProvider.overrideWithValue(SlowBattery([90, 60])),
      backendEnabledProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);

    final c = container.read(runControllerProvider.notifier);
    await c.start();
    // Long enough for the run's OWN start reading to land — otherwise there is
    // no start value, the end reading bails early, and the test would pass
    // while exercising nothing.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    c.stop(); // fires the slow end reading

    // Start again before that reading can land.
    await c.start();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(c.state.battery, isNull,
        reason: "the previous run's drain must not appear on the new run");
  });
}
