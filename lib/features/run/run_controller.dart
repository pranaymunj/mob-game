// run_controller.dart — Logic for the active run (Riverpod Notifier).
// Phase 2: subscribe to GPS, append points to the trail.
// Phase 3: detect closed loops and bank the enclosed polygon as a claim.
// Phase 4-5: persist claims to the server.
// Phase 6: track distance/time, auto-pause at car-like speed, and gate
// captures by implied speed (server re-validates authoritatively).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../models/run.dart';
import '../../services/analytics_service.dart';
import '../../services/gps_kalman.dart';
import '../../services/location_service.dart';
import 'run_state.dart';

class RunController extends Notifier<RunState> {
  StreamSubscription<GpsSample>? _sub;
  final List<DateTime> _times = []; // timestamps aligned with state.trail
  final List<List<double>> _allPoints = []; // full session path (for ghost runs)
  int _samplesSeen = 0; // for the GPS warm-up drop at the start of a run
  GpsKalman _kalman = GpsKalman(); // smooths raw GPS jitter (reset per run)

  // Runs are always walk mode (its speed cap is what the anti-cheat uses).
  final RunMode _mode = RunMode.walk;

  @override
  RunState build() {
    ref.onDispose(() => _sub?.cancel());
    return const RunState();
  }

  Future<void> start() async {
    final location = ref.read(locationServiceProvider);
    if (!await location.ensurePermission()) return; // no permission, no run

    if (ref.read(backendEnabledProvider)) {
      final backend = ref.read(backendServiceProvider);
      await backend.signIn();
      backend.recordActivity(); // count today toward the daily streak
    }

    _times.clear();
    _allPoints.clear();
    _samplesSeen = 0;
    _kalman = GpsKalman(q: GpsKalman.qFor(_mode.name)); // fresh filter per run
    state = RunState(isActive: true, startedAt: DateTime.now());
    AnalyticsService.log('run_started');

    _sub = location.positions().listen(_onPoint);
  }

  // Record why a GPS sample was discarded so the UI can show it live. Guessing
  // at GPS behaviour from a frozen 0m readout is what made this hard to fix.
  void _reject(String reason) {
    state = state.copyWith(lastReject: reason);
  }

  void _onPoint(GpsSample raw) {
    // Smooth the raw fix first: collapses GPS jitter while keeping real motion,
    // so the trail is clean and distance isn't inflated by drift.
    final s = _kalman.process(raw);

    final geometry = ref.read(geometryServiceProvider);
    final antiCheat = ref.read(antiCheatServiceProvider);
    final now = s.at;
    final point = [s.lng, s.lat];

    // ── GPS noise rejection ──────────────────────────────────────────────────
    // Without this, simply holding or waving a stationary phone accumulates
    // "distance" from GPS drift. Three independent checks must all pass.

    // Always surface signal quality — including for samples we reject — so the
    // UI can explain why nothing is happening (e.g. indoors) instead of just
    // sitting at 0m and looking broken.
    state = state.copyWith(
      gpsAccuracy: s.accuracy,
      lastSpeedMps: s.speedMps,
      samplesSeen: state.samplesSeen + 1,
      lastReject: state.lastReject,
    );

    // 0. Warm-up: the first fixes are coarse and then snap to the true
    //    position, which otherwise registers as an instant 10-30m "walk".
    if (_samplesSeen++ < AppConstants.gpsWarmupSamples) {
      _reject('warming up GPS');
      return;
    }

    // 1. Drop low-accuracy fixes (indoors / urban canyon) outright.
    if (s.accuracy > AppConstants.maxGpsAccuracyMeters) {
      _reject('weak signal (±${s.accuracy.toStringAsFixed(0)}m)');
      return;
    }

    // 2. Use the OS speed reading when it's available — it fuses more sensors
    //    than we can. iOS reports -1 for "unknown"; we must NOT treat that as
    //    stationary or a device that never reports speed could never track a
    //    run. The accuracy/step checks below carry the load in that case.
    if (s.speedMps >= 0 && s.speedMps < AppConstants.minWalkingSpeedMps) {
      _reject('standing still (${s.speedMps.toStringAsFixed(1)} m/s)');
      return;
    }

    // Speed check vs. the previous point (auto-pause if car-like).
    if (state.trail.isNotEmpty) {
      final prev = state.trail.last;
      final segMeters = geometry.distanceMeters(prev, point);

      // 3. Movement must clearly beat this fix's own uncertainty — at ±10m
      //    accuracy even a 16m "step" is still within plausible drift.
      final noiseFloor = math.max(
        AppConstants.minStepMeters,
        s.accuracy * AppConstants.accuracyNoiseFactor,
      );
      state = state.copyWith(lastStepMeters: segMeters);
      if (segMeters < noiseFloor) {
        _reject('step ${segMeters.toStringAsFixed(0)}m < '
            'noise floor ${noiseFloor.toStringAsFixed(0)}m');
        return;
      }

      final segSeconds = now.difference(_times.last).inMilliseconds / 1000.0;
      final speed = segSeconds > 0 ? segMeters / segSeconds : 0.0;

      // A teleport-sized jump is a GPS spike — discard instead of counting it.
      if (segSeconds > 0 && speed > AppConstants.maxPlausibleStepSpeedMps) {
        _reject('GPS spike (${speed.toStringAsFixed(1)} m/s)');
        return;
      }

      // Physical safety: if you're moving at vehicle speed, stop the run.
      if (antiCheat.impliesVehicle(speed)) {
        stop();
        state = state.copyWith(autoPausedForSpeed: true);
        return;
      }
      state = state.copyWith(
        sessionDistanceM: state.sessionDistanceM + segMeters,
      );
    }

    // Sample accepted — clear any stale rejection reason.
    state = state.copyWith(samplesUsed: state.samplesUsed + 1);

    _allPoints.add(point); // full path, kept across loop resets (for ghost runs)

    final trail = [...state.trail, point];
    _times.add(now);
    state = state.copyWith(trail: trail);
    _updatePreview(trail); // refresh the "close now" chip + button

    // Auto-capture: did the newest point close back onto the early path?
    final startIndex = geometry.loopStartIndex(trail);
    if (startIndex != null) {
      final loopSeconds =
          now.difference(_times[startIndex]).inMilliseconds / 1000.0;
      _bankLoop(geometry.enclosedPolygon(trail, startIndex),
          durationS: loopSeconds, closingPoint: point);
    }
  }

  // Manually force the claim: close the current trail with a straight line back
  // to the start. Rescues a capture when GPS drift stops auto-close firing.
  void claimNow() {
    if (!state.canClaimNow) return;
    final geometry = ref.read(geometryServiceProvider);
    final ring = geometry.enclosedPolygon([...state.trail], 0);
    final seconds = state.trail.length <= _times.length && _times.isNotEmpty
        ? DateTime.now().difference(_times.first).inMilliseconds / 1000.0
        : 0.0;
    _bankLoop(ring, durationS: seconds, closingPoint: state.trail.last);
  }

  // Refresh the live loop preview: gap back to start + enclosed area if closed
  // right now. Cheap enough to run every accepted point.
  void _updatePreview(List<List<double>> trail) {
    if (trail.length < 4) {
      state = state.copyWith(previewGapMeters: null, previewAreaM: 0);
      return;
    }
    final geometry = ref.read(geometryServiceProvider);
    final gap = geometry.distanceMeters(trail.last, trail.first);
    // Only bother computing area when you're close enough to actually close.
    var area = 0.0;
    if (gap <= AppConstants.manualClaimMeters * 1.5) {
      area = geometry.areaSqMeters(geometry.enclosedPolygon(trail, 0));
    }
    state = state.copyWith(previewGapMeters: gap, previewAreaM: area);
  }

  // The shared "bank a closed ring" path used by both auto and manual claim:
  // speed-gate, area-gate, log, reset the trail, and persist.
  void _bankLoop(List<List<double>> ring,
      {required double durationS, required List<double> closingPoint}) {
    final geometry = ref.read(geometryServiceProvider);
    final antiCheat = ref.read(antiCheatServiceProvider);
    final loopMeters = geometry.perimeterMeters(ring);
    final loopSpeed = durationS > 0 ? loopMeters / durationS : 0.0;

    // Consume the loop: reset the trail either way.
    _times
      ..clear()
      ..add(DateTime.now());

    if (!antiCheat.speedWithinCap(loopSpeed, _mode)) {
      AnalyticsService.log('capture_rejected', {
        'reason': 'speed',
        'implied_mps': loopSpeed.toStringAsFixed(1),
        'loop_m': loopMeters.round(),
      });
      state = state.copyWith(
        trail: [closingPoint],
        previewGapMeters: null,
        previewAreaM: 0,
        rejectedCount: state.rejectedCount + 1,
      );
      return;
    }

    final area = geometry.areaSqMeters(ring);
    if (area < AppConstants.minClaimAreaM2) {
      state = state.copyWith(
          trail: [closingPoint], previewGapMeters: null, previewAreaM: 0);
      return;
    }

    AnalyticsService.log('capture_succeeded', {
      'area_m2': area.round(),
      'loop_m': loopMeters.round(),
      'points': ring.length,
    });
    state = state.copyWith(
      trail: [closingPoint],
      previewGapMeters: null,
      previewAreaM: 0,
      claims: [...state.claims, ring],
      lastClaimArea: area,
      sessionAreaM: state.sessionAreaM + area,
    );

    if (ref.read(backendEnabledProvider)) {
      ref.read(backendServiceProvider).saveClaim(
            ring: ring,
            area: area,
            mode: _mode.name,
            distanceM: loopMeters,
            durationS: durationS,
          );
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    state = state.copyWith(isActive: false, endedAt: DateTime.now());

    // Log how the run actually went, including the GPS quality figures. This
    // is what lets a real-world capture failure be diagnosed from data rather
    // than asking the player to screenshot a telemetry readout.
    AnalyticsService.log('run_finished', {
      'distance_m': state.sessionDistanceM.round(),
      'duration_s': state.duration.inSeconds,
      'area_m2': state.sessionAreaM.round(),
      'captures': state.claims.length,
      'trail_points': state.trail.length,
      'gps_fixes_seen': state.samplesSeen,
      'gps_fixes_used': state.samplesUsed,
      'gps_accuracy_m': state.gpsAccuracy?.round(),
      'last_skip_reason': state.lastReject,
      'rejected_captures': state.rejectedCount,
      'auto_paused': state.autoPausedForSpeed,
    });

    // Bank the walk itself, whether or not a loop ever closed. Without this a
    // run that fails to capture records nothing and earns nothing.
    if (ref.read(backendEnabledProvider) && state.sessionDistanceM > 0) {
      ref.read(backendServiceProvider).finishRun(
            distanceM: state.sessionDistanceM,
            durationS: state.duration.inSeconds.toDouble(),
            mode: _mode.name,
          );
    }

    // Save this run as the ghost if it beats the stored best (server decides).
    if (ref.read(backendEnabledProvider) && _allPoints.length >= 2) {
      ref.read(backendServiceProvider).saveGhostRun(
            path: List<List<double>>.from(_allPoints),
            distanceM: state.sessionDistanceM,
          );
    }
  }
}

final runControllerProvider =
    NotifierProvider<RunController, RunState>(RunController.new);
