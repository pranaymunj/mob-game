// player.dart — A player: identity, color, total area, home base, and streak.

class Player {
  final String id;
  final String displayName;
  final int colorValue; // ARGB int
  final double totalArea; // square meters of turf currently held
  final double? homeLng; // block-level approximate home base (null if unset)
  final double? homeLat;
  final int currentStreak;
  final int longestStreak;
  final String? avatar; // single emoji chosen by the player
  final String colorHex; // kept so the picker can show the current selection
  final int coins; // soft currency, earned by claiming turf

  const Player({
    required this.id,
    required this.displayName,
    required this.colorValue,
    this.totalArea = 0,
    this.homeLng,
    this.homeLat,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.avatar,
    this.colorHex = '#56B4E9',
    this.coins = 0,
  });

  bool get hasHomeBase => homeLng != null && homeLat != null;
}
