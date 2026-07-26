// territory_backdrop.dart — Animated "claimed territory" artwork used behind the
// main menu. Slowly breathing polygons in the ownership palette so the menu
// feels like a living map, not a form.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class TerritoryBackdrop extends StatefulWidget {
  const TerritoryBackdrop({super.key});

  @override
  State<TerritoryBackdrop> createState() => _TerritoryBackdropState();
}

class _TerritoryBackdropState extends State<TerritoryBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _TerritoryPainter(_c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _TerritoryPainter extends CustomPainter {
  final double t; // 0..1 loop
  _TerritoryPainter(this.t);

  // Fixed pseudo-random layout so the art is stable between frames.
  static final _rng = math.Random(7);
  static final List<_Blob> _blobs = List.generate(7, (i) {
    return _Blob(
      cx: _rng.nextDouble(),
      cy: _rng.nextDouble(),
      r: 0.10 + _rng.nextDouble() * 0.16,
      sides: 5 + _rng.nextInt(3),
      rot: _rng.nextDouble() * math.pi,
      colorIndex: i % AppColors.ownershipPalette.length,
      phase: _rng.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _blobs) {
      // Gentle breathing so it feels alive.
      final pulse = 1 + 0.06 * math.sin((t + b.phase) * 2 * math.pi);
      final color = AppColors.ownershipPalette[b.colorIndex];
      final center = Offset(b.cx * size.width, b.cy * size.height);
      final radius = b.r * size.shortestSide * pulse;

      final path = Path();
      for (var i = 0; i <= b.sides; i++) {
        final a = b.rot + (i / b.sides) * 2 * math.pi;
        final p = center + Offset(math.cos(a) * radius, math.sin(a) * radius);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.06));
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TerritoryPainter old) => old.t != t;
}

class _Blob {
  final double cx, cy, r, rot, phase;
  final int sides, colorIndex;
  const _Blob({
    required this.cx,
    required this.cy,
    required this.r,
    required this.sides,
    required this.rot,
    required this.colorIndex,
    required this.phase,
  });
}
