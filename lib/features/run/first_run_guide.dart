// first_run_guide.dart — Makes a new player's first capture un-failable.
//
// A first-timer opening a map and being told "walk a loop" doesn't know how
// big, which way, or when it counts. So we draw an actual suggested square
// next to them and coach them around it, step by step. Every game that
// depends on a physical action (Pokémon GO's first catch) scripts this.

import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class FirstRunGuide {
  static const _kDone = 'first_capture_done';

  /// Side length of the suggested loop. Big enough to beat GPS noise
  /// (accuracy is ~±13m in a built-up area), small enough to walk in ~2 min.
  static const double suggestedSideM = 60;

  static Future<bool> isComplete() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kDone) ?? false;
  }

  static Future<void> markComplete() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDone, true);
  }

  /// A square ring starting at the player's position, extending north-east.
  /// Returned as a closed list of [lng, lat] points.
  static List<List<double>> suggestedLoop({
    required double lng,
    required double lat,
    double sideM = suggestedSideM,
  }) {
    // Degrees per metre at this latitude.
    const mPerDegLat = 110574.0;
    final mPerDegLng = 111320.0 * math.cos(lat * math.pi / 180.0);

    final dLat = sideM / mPerDegLat;
    final dLng = sideM / mPerDegLng;

    return [
      [lng, lat],
      [lng + dLng, lat],
      [lng + dLng, lat + dLat],
      [lng, lat + dLat],
      [lng, lat], // closed
    ];
  }

  /// Coaching for the run HUD, based on how far the player has got.
  /// [metersToClose] is null until there's enough trail to measure.
  static ({String title, String body}) coach({
    required int trailPoints,
    required double? metersToClose,
    required double distanceWalked,
  }) {
    if (distanceWalked < 15) {
      return (
        title: 'Follow the dotted square',
        body: 'Start walking along the guide on your map. Any direction — just '
            'begin.',
      );
    }
    if (trailPoints < 3 || metersToClose == null) {
      return (
        title: 'Keep going — you\'re drawing a trail',
        body: 'Walk the first side of the square, then turn the corner.',
      );
    }
    if (metersToClose > 40) {
      return (
        title: 'Now loop back around',
        body: 'Turn and head back toward where you started — '
            '${metersToClose.toStringAsFixed(0)} m to go.',
      );
    }
    return (
      title: 'Almost! Close the loop',
      body: 'Get within a few steps of your starting point and the middle '
          'becomes yours.',
    );
  }
}
