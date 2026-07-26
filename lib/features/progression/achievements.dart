// achievements.dart — Badge definitions, unlocked from PlayerStats.

import 'package:flutter/material.dart';

import '../../models/player_stats.dart';

class Achievement {
  final String name;
  final String description;
  final IconData icon;
  final bool Function(PlayerStats) unlocked;
  const Achievement(this.name, this.description, this.icon, this.unlocked);
}

const _achievements = <Achievement>[
  Achievement('First Claim', 'Complete your first run', Icons.flag,
      _firstClaim),
  Achievement('Trailblazer', 'Complete 10 runs', Icons.directions_walk,
      _trailblazer),
  Achievement('Landowner', 'Make 1,000 m² of territory', Icons.terrain,
      _landowner),
  Achievement('Baron', 'Make 10,000 m² of territory', Icons.landscape,
      _baron),
  Achievement('Empire', 'Make 100,000 m² of territory', Icons.public,
      _empire),
  Achievement('Streak Starter', 'Reach a 3-day streak',
      Icons.local_fire_department, _streak3),
  Achievement('Dedicated', 'Reach a 7-day streak', Icons.whatshot, _streak7),
];

bool _firstClaim(PlayerStats s) => s.runCount >= 1;
bool _trailblazer(PlayerStats s) => s.runCount >= 10;
bool _landowner(PlayerStats s) => s.lifetimeArea >= 1000;
bool _baron(PlayerStats s) => s.lifetimeArea >= 10000;
bool _empire(PlayerStats s) => s.lifetimeArea >= 100000;
bool _streak3(PlayerStats s) => s.longestStreak >= 3;
bool _streak7(PlayerStats s) => s.longestStreak >= 7;

List<Achievement> get allAchievements => _achievements;
