// run.dart — A single gameplay run: distance/time/area for stats + anti-cheat.

enum RunMode { walk, run, cycle }

class Run {
  final String id;
  final String playerId;
  final double distance; // meters
  final double areaGained; // square meters
  final Duration duration;
  final DateTime startedAt;
  final RunMode mode;

  const Run({
    required this.id,
    required this.playerId,
    required this.distance,
    required this.areaGained,
    required this.duration,
    required this.startedAt,
    this.mode = RunMode.walk,
  });
}
