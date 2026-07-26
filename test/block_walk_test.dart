// block_walk_test.dart — Simulates walking a real city block with the GPS
// noise profile measured on-device (±13m accuracy, 0.3 m/s reported speed,
// a fix roughly every 4m) and asserts that a loop actually gets captured.
//
// This exists because loop capture — the core of the game — had never
// succeeded in the real world, and each field test cost a round trip. If the
// mechanic is broken, it should fail here first.

import 'dart:math' as math;

import 'package:claimr/core/providers.dart';
import 'package:claimr/features/run/run_controller.dart';
import 'package:claimr/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

// Roughly-Mumbai scale factors (the field data came from there).
const _baseLng = 72.8500;
const _baseLat = 19.1200;
const _mPerDegLat = 110574.0;
const _mPerDegLng = 104000.0; // cos(19°) * 111320

/// Walk a square block [side] metres per side, emitting a fix every [stepM]
/// metres with [accuracy] metres of positional noise.
List<GpsSample> walkBlock({
  required double side,
  double stepM = 4,
  double accuracy = 13,
  double noise = 6,
  double speed = 0.3,
  int seed = 42,
}) {
  final rng = math.Random(seed);
  final samples = <GpsSample>[];
  var t = DateTime(2026, 1, 1, 9);

  // Corners of the square, walked in order and back to the start.
  final corners = <List<double>>[
    [0, 0],
    [side, 0],
    [side, side],
    [0, side],
    [0, 0],
  ];

  for (var c = 0; c < corners.length - 1; c++) {
    final from = corners[c], to = corners[c + 1];
    final legX = to[0] - from[0], legY = to[1] - from[1];
    final legLen = math.sqrt(legX * legX + legY * legY);
    final steps = (legLen / stepM).floor();

    for (var i = 0; i < steps; i++) {
      final f = i / steps;
      // True position along the leg, plus GPS wobble.
      final x = from[0] + legX * f + (rng.nextDouble() - 0.5) * noise;
      final y = from[1] + legY * f + (rng.nextDouble() - 0.5) * noise;
      samples.add(GpsSample(
        lng: _baseLng + x / _mPerDegLng,
        lat: _baseLat + y / _mPerDegLat,
        speedMps: speed,
        accuracy: accuracy,
        at: t,
      ));
      // ~3s between fixes at walking pace.
      t = t.add(const Duration(seconds: 3));
    }
  }
  return samples;
}

Future<RunController> runWalk(List<GpsSample> samples) async {
  final container = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(FakeLocationService(samples)),
    backendEnabledProvider.overrideWithValue(false),
  ]);
  addTearDown(container.dispose);
  final controller = container.read(runControllerProvider.notifier);
  await controller.start();
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return controller;
}

void main() {
  test('walking a 100m block captures turf', () async {
    final samples = walkBlock(side: 100);
    final c = await runWalk(samples);
    final s = c.state;

    // Diagnostics first — if this fails we want to know why, not just that.
    // ignore: avoid_print
    print('100m block -> fixes:${samples.length} trail:${s.trail.length} '
        'distance:${s.sessionDistanceM.toStringAsFixed(0)}m '
        'captures:${s.claims.length} area:${s.sessionAreaM.toStringAsFixed(0)}m² '
        'rejected:${s.rejectedCount} skip:${s.lastReject}');

    expect(s.sessionDistanceM, greaterThan(200),
        reason: 'a 400m walk should register substantial distance');
    expect(s.claims.length, greaterThanOrEqualTo(1),
        reason: 'returning to the start should close a loop and claim turf');
    expect(s.sessionAreaM, greaterThan(1000),
        reason: 'a 100m block encloses ~10,000 m²');
  });

  test('walking a small 40m block still captures', () async {
    final samples = walkBlock(side: 40);
    final c = await runWalk(samples);
    final s = c.state;
    // ignore: avoid_print
    print('40m block  -> fixes:${samples.length} trail:${s.trail.length} '
        'distance:${s.sessionDistanceM.toStringAsFixed(0)}m '
        'captures:${s.claims.length} area:${s.sessionAreaM.toStringAsFixed(0)}m² '
        'skip:${s.lastReject}');
    expect(s.claims.length, greaterThanOrEqualTo(1),
        reason: 'a small block is the realistic worst case and must still work');
  });

  test('manual claim closes a loop that stops short of the start', () async {
    // Walk 3 sides of a 100m block and stop ~40m short of the start — too far
    // for auto-close, but within manual-claim range. claimNow() must capture.
    final rng = math.Random(3);
    final samples = <GpsSample>[];
    var t = DateTime(2026, 1, 1, 9);
    final corners = <List<double>>[
      [0, 0], [100, 0], [100, 100], [0, 100], [0, 40], // stop 40m short
    ];
    for (var c = 0; c < corners.length - 1; c++) {
      final from = corners[c], to = corners[c + 1];
      final legX = to[0] - from[0], legY = to[1] - from[1];
      final legLen = math.sqrt(legX * legX + legY * legY);
      for (var i = 0; i < (legLen / 4).floor(); i++) {
        final f = i / (legLen / 4);
        samples.add(GpsSample(
          lng: _baseLng + (from[0] + legX * f + (rng.nextDouble() - 0.5) * 4) /
              _mPerDegLng,
          lat: _baseLat + (from[1] + legY * f + (rng.nextDouble() - 0.5) * 4) /
              _mPerDegLat,
          speedMps: 0.4,
          accuracy: 12,
          at: t,
        ));
        t = t.add(const Duration(seconds: 3));
      }
    }

    final c = await runWalk(samples);
    // Auto-close should NOT have fired (ended 40m from start).
    // ignore: avoid_print
    print('short-stop -> auto captures:${c.state.claims.length} '
        'canClaimNow:${c.state.canClaimNow} preview:${c.state.previewAreaM.toStringAsFixed(0)}m²');
    expect(c.state.canClaimNow, isTrue,
        reason: '40m from start with a big loop should allow manual claim');

    c.claimNow();
    expect(c.state.claims.length, 1,
        reason: 'claimNow must bank the enclosed area');
    expect(c.state.sessionAreaM, greaterThan(5000));
  });

  test('walking a straight line out and back claims nothing', () async {
    // Out 150m and straight back: encloses no area, so nothing should be
    // claimed even though the player returns to their start.
    final rng = math.Random(1);
    final samples = <GpsSample>[];
    var t = DateTime(2026, 1, 1, 9);
    for (final leg in [1, -1]) {
      for (var d = 0; d < 150; d += 4) {
        final x = (leg == 1 ? d : 150 - d) + (rng.nextDouble() - 0.5) * 4;
        samples.add(GpsSample(
          lng: _baseLng + x / _mPerDegLng,
          lat: _baseLat,
          speedMps: 1.2,
          accuracy: 8,
          at: t,
        ));
        t = t.add(const Duration(seconds: 3));
      }
    }
    final c = await runWalk(samples);
    // ignore: avoid_print
    print('line out+back -> captures:${c.state.claims.length} '
        'area:${c.state.sessionAreaM.toStringAsFixed(0)}m²');
    expect(c.state.sessionAreaM, lessThan(1000),
        reason: 'retracing a line encloses no meaningful area');
    expect(c.state.claims, isEmpty,
        reason: 'a zero-area loop must not bank an empty claim');
  });
}
