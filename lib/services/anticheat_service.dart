// anticheat_service.dart — Speed gating + plausibility checks (Phase 6).
// The client does a first pass for UX (auto-pause, "too fast" feedback); the
// SERVER (claim_turf) is the authoritative gate — never trust the client.

import '../core/constants.dart';
import '../models/run.dart';

class AntiCheatService {
  // Max plausible speed for a mode, in meters/second.
  double capFor(RunMode mode) => switch (mode) {
        RunMode.walk => AppConstants.walkCapMps,
        RunMode.run => AppConstants.runCapMps,
        RunMode.cycle => AppConstants.cycleCapMps,
      };

  // Allow a little headroom for GPS noise (must match the server tolerance).
  static const double tolerance = 1.25;

  bool speedWithinCap(double speedMps, RunMode mode) =>
      speedMps <= capFor(mode) * tolerance;

  // Above this, movement implies a vehicle — auto-pause the run for safety.
  static const double vehicleSpeedMps = 13.0; // ~47 km/h
  bool impliesVehicle(double speedMps) => speedMps > vehicleSpeedMps;
}
