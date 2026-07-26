// constants.dart — App-wide constants (tuning knobs, mode caps, batching).
// Keep game-balance and cost numbers here so they are easy to find and tweak.

class AppConstants {
  AppConstants._();

  static const String appName = 'Claimr';

  // Cost discipline (CLAUDE.md Part 5): batch GPS updates, don't stream every frame.
  static const Duration gpsBatchInterval = Duration(seconds: 3);

  // Anti-cheat speed caps in meters/second (validated server-side too).
  static const double walkCapMps = 2.5; // ~9 km/h
  static const double runCapMps = 6.5; // ~23 km/h
  static const double cycleCapMps = 12.0; // ~43 km/h

  // Loop detection: how close (meters) the trail must return to its start.
  static const double loopCloseMeters = 25.0;

  // A "loop" that encloses less than this is degenerate — e.g. walking out and
  // straight back closes a loop geometrically but fences off nothing. Without
  // this floor it would bank an empty claim and toast "+0 m²".
  static const double minClaimAreaM2 = 50.0;

  // Manual claim: if you're within this distance of your start, the "Claim"
  // button can force-close the loop with a straight line. Rescues captures
  // when GPS drift stops the auto-close from triggering.
  static const double manualClaimMeters = 100.0;

  // GPS quality gate: ignore fixes worse than this horizontal accuracy (meters).
  // Filters out jittery indoor/urban-canyon points that would corrupt the trail.
  static const double maxGpsAccuracyMeters = 20.0;

  // Ignore micro-jitter: displacement from the last accepted point must reach
  // this before we count it. Rejected samples deliberately do NOT move the
  // anchor, so successive small GPS steps accumulate until they clear the bar —
  // that's what makes this work when fixes arrive every ~4m.
  static const double minStepMeters = 10.0;

  // Only a near-total standstill is rejected on speed alone. Measured in a
  // dense urban area, iOS reported just 0.3 m/s for a real walk (Doppler speed
  // degrades badly between tall buildings), so anything higher than this
  // wrongly blocks genuine walking. Displacement does the real filtering.
  static const double minWalkingSpeedMps = 0.2;

  // Displacement must exceed the fix's accuracy by this factor. Kept at 1.0:
  // at ±13m accuracy you must genuinely travel 13m, which drift rarely
  // sustains, while a real walk clears it in a few seconds.
  static const double accuracyNoiseFactor = 1.0;

  // Drop the first fixes of a run: phones return a coarse/cached location and
  // then snap to the true one, which looks like a sudden 10-30m sprint.
  static const int gpsWarmupSamples = 2;

  // A single step implying more than this is a GPS spike, not a walk — discard
  // it rather than adding it to the distance total.
  static const double maxPlausibleStepSpeedMps = 4.0;

  // The local player's color for now (index into the colorblind-safe palette).
  // Real per-player colors arrive with accounts in Phase 4.
  static const int currentPlayerColorIndex = 1; // sky blue
}
