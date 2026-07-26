// player_stats.dart — Lifetime progression: territory made, runs, and the
// derived level / XP used for the progress bar and achievements.
//
// XP == lifetime area in m². Level curve: level n starts at (n-1)^2 * 500 XP,
// so each level costs a bit more than the last.

import 'dart:math' as math;

class PlayerStats {
  final double lifetimeArea; // "territory made" — only ever grows
  final int runCount;
  final double currentArea;
  final int longestStreak;
  final int currentStreak;

  const PlayerStats({
    required this.lifetimeArea,
    required this.runCount,
    required this.currentArea,
    required this.longestStreak,
    required this.currentStreak,
  });

  static const double _perLevel = 500; // XP scale

  int get level => (math.sqrt(lifetimeArea / _perLevel)).floor() + 1;

  double _levelStartXp(int lvl) => math.pow(lvl - 1, 2) * _perLevel * 1.0;

  double get _thisLevelStart => _levelStartXp(level);
  double get _nextLevelStart => _levelStartXp(level + 1);

  // 0..1 progress toward the next level.
  double get levelProgress {
    final span = _nextLevelStart - _thisLevelStart;
    if (span <= 0) return 0;
    return ((lifetimeArea - _thisLevelStart) / span).clamp(0, 1);
  }

  int get xpIntoLevel => (lifetimeArea - _thisLevelStart).round();
  int get xpForLevel => (_nextLevelStart - _thisLevelStart).round();
}
