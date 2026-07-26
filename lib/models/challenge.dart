// challenge.dart — Today's shared daily challenge and this player's progress.

class Challenge {
  final String metric; // 'area' | 'loops' | 'distance'
  final double target;
  final String label;
  final double progress;
  final bool completed;

  const Challenge({
    required this.metric,
    required this.target,
    required this.label,
    required this.progress,
    required this.completed,
  });

  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0, 1);

  // Human-readable "progress / target" with the right unit.
  String get progressLabel {
    switch (metric) {
      case 'area':
        return '${progress.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} m²';
      case 'distance':
        return '${progress.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} m';
      default: // loops
        return '${progress.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}';
    }
  }
}
