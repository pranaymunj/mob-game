// capture_celebration.dart — The big arcade payoff when you claim turf.
//
// This is the moment the whole game exists for, so it goes loud: a screen
// flash, a radial burst of particles in the player colour, a "TURF CLAIMED!"
// banner, and the area number exploding up from 0. Shown as a transient
// overlay above the map, then it fades itself out.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class CaptureCelebration extends StatefulWidget {
  final double areaM2;
  final int coins;
  final String areaLabel; // pre-formatted for the player's unit setting
  final VoidCallback onDone;

  const CaptureCelebration({
    super.key,
    required this.areaM2,
    required this.coins,
    required this.areaLabel,
    required this.onDone,
  });

  @override
  State<CaptureCelebration> createState() => _CaptureCelebrationState();
}

class _CaptureCelebrationState extends State<CaptureCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(28, (_) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 120 + rng.nextDouble() * 220;
      return _Particle(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed,
        size: 5 + rng.nextDouble() * 9,
        color: AppColors.ownershipPalette[
            rng.nextInt(AppColors.ownershipPalette.length)],
        spin: (rng.nextDouble() - 0.5) * 6,
      );
    });

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Eased sub-intervals so the elements land in a satisfying sequence.
  double _seg(double start, double end, {Curve curve = Curves.easeOut}) {
    final raw = ((_c.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final flash = (1 - _seg(0, 0.18)) * 0.5; // quick white pop
          final burst = _seg(0.0, 0.6);
          final bannerIn = _seg(0.1, 0.35, curve: Curves.elasticOut);
          final countUp = _seg(0.2, 0.7);
          final fade = 1 - _seg(0.8, 1.0);

          final shownArea = (widget.areaM2 * countUp);

          return Opacity(
            opacity: fade,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Screen flash.
                Positioned.fill(
                  child: ColoredBox(
                      color: Colors.white.withValues(alpha: flash)),
                ),
                // Radial particle burst.
                CustomPaint(
                  size: Size.infinite,
                  painter: _BurstPainter(_particles, burst),
                ),
                // Banner + numbers.
                Transform.scale(
                  scale: 0.6 + 0.4 * bannerIn,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Banner(color: AppColors.accent),
                      const SizedBox(height: 14),
                      Text(
                        _formatArea(shownArea, widget.areaLabel),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: AppColors.accent.withValues(alpha: 0.9),
                                blurRadius: 28),
                          ],
                        ),
                      ),
                      if (widget.coins > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('🪙 +${(widget.coins * countUp).round()}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Reuse the caller's unit label but swap in the animating number.
  static String _formatArea(double animated, String finalLabel) {
    // finalLabel looks like "1,234 m²" or "1234 ft²" — take its unit suffix.
    final unit = finalLabel.replaceAll(RegExp(r'[0-9.,\s]'), '');
    return '${animated.toStringAsFixed(0)} $unit';
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  const _Banner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 24),
        ],
      ),
      child: const Text(
        'TURF CLAIMED!',
        style: TextStyle(
          color: Colors.black,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _Particle {
  final double dx, dy, size, spin;
  final Color color;
  const _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.spin,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1
  _BurstPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1 - t).clamp(0.0, 1.0);

    for (final p in particles) {
      final pos = center + Offset(p.dx * t, p.dy * t - 40 * t * t); // slight arc
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}
