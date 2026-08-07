// battery_service.dart — Reads the device battery level so a run can report
// what it actually cost.
//
// Battery is the most likely reason a walking game gets deleted: a player who
// finishes a 40-minute run on 25% less charge uninstalls and writes "great
// idea, killed my phone". Until now measuring that meant squinting at iOS
// Settings and guessing, which is why it never got measured. This makes every
// real run produce the number by itself.
//
// Behind an interface like every other service (CLAUDE.md Part 3), so the
// run controller can be tested without a device.

import 'package:battery_plus/battery_plus.dart';

abstract class BatteryService {
  /// Battery charge 0–100, or null if the platform won't say.
  Future<int?> level();

  /// True while the device is plugged in — a run spent on charge tells us
  /// nothing about drain, so it has to be excluded rather than reported as 0%.
  Future<bool> isCharging();
}

class DeviceBatteryService implements BatteryService {
  final Battery _battery = Battery();

  @override
  Future<int?> level() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      // Simulators and some Android OEMs simply don't answer. Measurement is
      // never worth breaking a run over.
      return null;
    }
  }

  @override
  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      return false;
    }
  }
}

/// What a run cost, derived from a start and end reading.
///
/// Kept as a plain value type with no plugin behind it so the arithmetic —
/// the part that is easy to get quietly wrong — is directly testable.
class BatteryUsage {
  final int startPercent;
  final int endPercent;
  final Duration duration;
  final double distanceMeters;
  final bool chargedDuringRun;

  const BatteryUsage({
    required this.startPercent,
    required this.endPercent,
    required this.duration,
    required this.distanceMeters,
    this.chargedDuringRun = false,
  });

  /// Percentage points consumed. Clamped at zero: the level can tick UP a
  /// point mid-run from temperature or charging, and a negative "drain" would
  /// poison any average built from these.
  int get drainPercent =>
      (startPercent - endPercent) < 0 ? 0 : startPercent - endPercent;

  /// Percent per hour — the figure that predicts whether the phone survives a
  /// long walk, and the one comparable across runs of different lengths.
  double? get percentPerHour {
    if (chargedDuringRun) return null;
    final hours = duration.inMilliseconds / 3600000.0;
    if (hours <= 0.01) return null; // under ~36s, quantisation dominates
    return drainPercent / hours;
  }

  /// Percent per kilometre walked.
  double? get percentPerKm {
    if (chargedDuringRun) return null;
    final km = distanceMeters / 1000.0;
    if (km <= 0.05) return null;
    return drainPercent / km;
  }

  /// Whether this reading is worth reporting at all. A plugged-in run, or one
  /// too short for the battery to have moved a whole point, tells us nothing —
  /// and a confidently wrong number is worse than none.
  bool get isMeaningful => !chargedDuringRun && percentPerHour != null;

  Map<String, dynamic> toEventProps() => {
        'battery_start': startPercent,
        'battery_end': endPercent,
        'battery_drain_pct': drainPercent,
        'battery_pct_per_hour': percentPerHour?.toStringAsFixed(1),
        'battery_pct_per_km': percentPerKm?.toStringAsFixed(1),
        'battery_charging': chargedDuringRun,
      };
}
