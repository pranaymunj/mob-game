// run_state.dart — Immutable state for an active run: the live trail, turf
// claimed this session, safety/anti-cheat signals, and run stats for the
// end-of-run summary.

import '../../core/constants.dart';
import '../../services/battery_service.dart';

class RunState {
  final bool isActive;
  final List<List<double>> trail; // [lng, lat] points collected this run
  final List<List<List<double>>> claims; // closed rings claimed this session
  final double lastClaimArea; // sq meters of the most recent claim (for UI)
  final bool autoPausedForSpeed; // set true when we auto-pause at car speed
  final int rejectedCount; // captures rejected client-side for over-cap speed
  final int smallLoopCount; // loops closed but discarded for being too small
  final double? gpsAccuracy; // last fix's accuracy in metres (null = no fix yet)

  // Live GPS diagnostics — so a run that isn't counting can explain itself
  // instead of silently sitting at 0m.
  final double? lastSpeedMps; // OS-reported speed (-1 = unknown)
  final double? lastStepMeters; // distance from the previous accepted point
  final String? lastReject; // why the most recent sample was discarded
  final int samplesSeen; // total GPS samples received this run
  final int samplesUsed; // samples that passed every filter

  // Live loop preview: distance from where you are back to your start, and the
  // area you'd enclose if you closed the loop right now. Drive the "Claim now"
  // button + the dotted preview line.
  final double? previewGapMeters;
  final double previewAreaM;

  // Trail vulnerability: the instant the OLDEST point on the trail expires and
  // drops off the start. Stored as an instant, not a remaining duration, so the
  // countdown keeps ticking between GPS fixes — state only changes when a point
  // arrives, which on a slow walk can be many seconds apart.
  final DateTime? trailExpiresAt;

  // Run stats (for the summary screen).
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double sessionDistanceM; // total distance walked this run
  final double sessionAreaM; // total area claimed this run

  // What the run cost in battery. Null until the reading lands after stop(),
  // and on devices that won't report a level at all.
  final BatteryUsage? battery;

  const RunState({
    this.isActive = false,
    this.trail = const [],
    this.claims = const [],
    this.lastClaimArea = 0,
    this.autoPausedForSpeed = false,
    this.rejectedCount = 0,
    this.smallLoopCount = 0,
    this.gpsAccuracy,
    this.lastSpeedMps,
    this.lastStepMeters,
    this.lastReject,
    this.samplesSeen = 0,
    this.samplesUsed = 0,
    this.previewGapMeters,
    this.previewAreaM = 0,
    this.trailExpiresAt,
    this.startedAt,
    this.endedAt,
    this.sessionDistanceM = 0,
    this.sessionAreaM = 0,
    this.battery,
  });

  Duration get duration => (startedAt == null)
      ? Duration.zero
      : (endedAt ?? DateTime.now()).difference(startedAt!);

  /// Time left before the oldest point drops off, recomputed on read so the
  /// display counts down without needing new state.
  Duration? get trailExpiresIn {
    if (trailExpiresAt == null) return null;
    final left = trailExpiresAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  // True once the oldest point is close enough to expiring that the player
  // should be told to close the loop now.
  bool get trailAtRisk {
    if (!isActive || trail.length < 2) return false;
    final left = trailExpiresIn;
    return left != null && left <= AppConstants.trailExpiryWarning;
  }

  // True when you're close enough to your start, with enough area, to force
  // the claim manually (the "Claim" button rescue).
  bool get canClaimNow =>
      isActive &&
      trail.length >= 4 &&
      previewGapMeters != null &&
      previewGapMeters! <= AppConstants.manualClaimMeters &&
      previewAreaM >= AppConstants.minClaimAreaM2;

  RunState copyWith({
    bool? isActive,
    double? previewGapMeters,
    double? previewAreaM,
    DateTime? trailExpiresAt,
    List<List<double>>? trail,
    List<List<List<double>>>? claims,
    double? lastClaimArea,
    bool? autoPausedForSpeed,
    int? rejectedCount,
    int? smallLoopCount,
    double? gpsAccuracy,
    double? lastSpeedMps,
    double? lastStepMeters,
    String? lastReject,
    int? samplesSeen,
    int? samplesUsed,
    DateTime? startedAt,
    DateTime? endedAt,
    double? sessionDistanceM,
    double? sessionAreaM,
    BatteryUsage? battery,
  }) =>
      RunState(
        isActive: isActive ?? this.isActive,
        trail: trail ?? this.trail,
        claims: claims ?? this.claims,
        lastClaimArea: lastClaimArea ?? this.lastClaimArea,
        autoPausedForSpeed: autoPausedForSpeed ?? this.autoPausedForSpeed,
        rejectedCount: rejectedCount ?? this.rejectedCount,
        smallLoopCount: smallLoopCount ?? this.smallLoopCount,
        gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
        lastSpeedMps: lastSpeedMps ?? this.lastSpeedMps,
        lastStepMeters: lastStepMeters ?? this.lastStepMeters,
        // Deliberately overwritable with null: a sample that passes clears the
        // previous rejection reason.
        lastReject: lastReject,
        samplesSeen: samplesSeen ?? this.samplesSeen,
        samplesUsed: samplesUsed ?? this.samplesUsed,
        previewGapMeters: previewGapMeters ?? this.previewGapMeters,
        previewAreaM: previewAreaM ?? this.previewAreaM,
        trailExpiresAt: trailExpiresAt ?? this.trailExpiresAt,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        sessionDistanceM: sessionDistanceM ?? this.sessionDistanceM,
        sessionAreaM: sessionAreaM ?? this.sessionAreaM,
        battery: battery ?? this.battery,
      );
}
