// cosmetic_preview.dart — Live, physics-driven previews for shop cosmetics.
//
// Instead of a flat colour swatch, each trail skin / turf style renders its
// real character with a tiny particle system: embers that rise with buoyancy,
// frost that falls under gravity and sways, neon sparks that shoot, void motes
// that orbit. Every particle carries position, velocity, acceleration and a
// lifetime, so the motion is genuine physics rather than a canned loop.
//
// Built on CustomPainter with one Ticker per preview — no assets, no extra
// packages, and it themes/scales with the rest of the UI.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme.dart';
import 'cosmetics_catalog.dart';

// How a particle moves — each maps to a small physics rule in [_step].
enum _Motion { rise, fall, shoot, orbit, drift }

// The static backdrop drawn behind the particles for turf styles.
enum _Bg { none, solid, outline, glow, hatch }

class _Spec {
  final _Motion motion;
  final _Bg bg;
  final List<Color> palette; // particles pick from these
  final int count;
  const _Spec(this.motion, this.bg, this.palette, this.count);

  // Turf styles use a land-plot look instead of a particle field.
  bool get isTurf => bg != _Bg.none;
}

// Per-cosmetic emitter tuning. Colours lean into each skin's identity.
_Spec _specFor(CosmeticInfo info) {
  switch (info.key) {
    case 'trail_flame':
      return const _Spec(_Motion.rise, _Bg.none, [
        Color(0xFFFFE082), Color(0xFFFF8F00), Color(0xFFFF5722), Color(0xFFD84315),
      ], 16);
    case 'trail_ice':
      return const _Spec(_Motion.fall, _Bg.none, [
        Color(0xFFE1F5FE), Color(0xFF80D8FF), Color(0xFFB3E5FC), Colors.white,
      ], 16);
    case 'trail_neon':
      return const _Spec(_Motion.shoot, _Bg.none, [
        Color(0xFF00E676), Color(0xFF69F0AE), Color(0xFFB9F6CA),
      ], 12);
    case 'trail_void':
      return const _Spec(_Motion.orbit, _Bg.none, [
        Color(0xFFB388FF), Color(0xFF7C4DFF), Color(0xFFE1BEE7),
      ], 14);
    case 'trail_classic':
      return _Spec(_Motion.drift, _Bg.none, [info.color, Colors.white], 10);
    // Turf styles render as land plots (see _TurfPlotPainter), so they emit
    // no particles — the plot + flag carry the look.
    case 'turf_solid':
      return _Spec(_Motion.drift, _Bg.solid, [info.color], 0);
    case 'turf_outline':
      return _Spec(_Motion.drift, _Bg.outline, [info.color], 0);
    case 'turf_glow':
      return _Spec(_Motion.drift, _Bg.glow, [info.color], 0);
    case 'turf_hatch':
      return _Spec(_Motion.drift, _Bg.hatch, [info.color], 0);
    default:
      return _Spec(_Motion.drift, _Bg.none, [info.color], 10);
  }
}

class _Particle {
  double x, y, vx, vy, ax, ay, life, maxLife, size, phase;
  Color color;
  // Polar state for orbiting motion.
  double angle, radius, angVel;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ax,
    required this.ay,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.phase,
    required this.color,
    this.angle = 0,
    this.radius = 0,
    this.angVel = 0,
  });
}

class CosmeticPreview extends StatefulWidget {
  final CosmeticInfo info;
  final double size;
  const CosmeticPreview({super.key, required this.info, this.size = 54});

  @override
  State<CosmeticPreview> createState() => _CosmeticPreviewState();
}

class _CosmeticPreviewState extends State<CosmeticPreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _rng = math.Random();
  final List<_Particle> _particles = [];
  late final _Spec _spec = _specFor(widget.info);
  Duration _last = Duration.zero;
  double _t = 0; // seconds since start, for background pulses

  @override
  void initState() {
    super.initState();
    final s = Size.square(widget.size);
    for (var i = 0; i < _spec.count; i++) {
      final p = _spawn(s);
      // Stagger initial lifetimes so they don't all pulse in lockstep.
      p.life = _rng.nextDouble() * p.maxLife;
      _particles.add(p);
    }
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.05) dt = 0.016; // clamp hitches
    _t += dt;
    final s = Size.square(widget.size);
    for (var i = 0; i < _particles.length; i++) {
      _step(_particles[i], s, dt);
      if (_dead(_particles[i], s)) _particles[i] = _spawn(s);
    }
    if (mounted) setState(() {});
  }

  Color _pick() =>
      _spec.palette[_rng.nextInt(_spec.palette.length)];

  double _rand(double a, double b) => a + _rng.nextDouble() * (b - a);

  // Fresh particle positioned + velocity-seeded for this skin's motion.
  _Particle _spawn(Size s) {
    final c = _pick();
    switch (_spec.motion) {
      case _Motion.rise: // embers: born low, float up, buoyant
        return _Particle(
          x: _rand(s.width * 0.2, s.width * 0.8),
          y: s.height * _rand(0.8, 1.0),
          vx: _rand(-6, 6),
          vy: _rand(-26, -16),
          ax: 0,
          ay: _rand(-10, -4), // buoyancy accelerates the rise
          life: _rand(0.9, 1.5),
          maxLife: 1.5,
          size: _rand(2.5, 5.5),
          phase: _rand(0, math.pi * 2),
          color: c,
        );
      case _Motion.fall: // frost: born high, fall, gravity + sway
        return _Particle(
          x: _rand(0, s.width),
          y: _rand(-4, s.height * 0.2),
          vx: _rand(-3, 3),
          vy: _rand(8, 16),
          ax: 0,
          ay: _rand(6, 12), // gravity
          life: _rand(1.0, 1.8),
          maxLife: 1.8,
          size: _rand(2, 4),
          phase: _rand(0, math.pi * 2),
          color: c,
        );
      case _Motion.shoot: // neon sparks: fast left-to-right streaks
        return _Particle(
          x: _rand(-6, s.width * 0.3),
          y: _rand(s.height * 0.2, s.height * 0.8),
          vx: _rand(70, 130),
          vy: _rand(-10, 10),
          ax: 0,
          ay: 0,
          life: _rand(0.4, 0.8),
          maxLife: 0.8,
          size: _rand(2, 3.5),
          phase: 0,
          color: c,
        );
      case _Motion.orbit: // void motes: orbit the centre, spiralling
        final radius = _rand(s.width * 0.12, s.width * 0.4);
        return _Particle(
          x: 0, y: 0, vx: 0, vy: 0, ax: 0, ay: 0,
          life: _rand(1.2, 2.2),
          maxLife: 2.2,
          size: _rand(2, 4),
          phase: _rand(0, math.pi * 2),
          color: c,
          angle: _rand(0, math.pi * 2),
          radius: radius,
          angVel: _rand(1.4, 2.6) * (_rng.nextBool() ? 1 : -1),
        );
      case _Motion.drift: // gentle floating motes
        return _Particle(
          x: _rand(0, s.width),
          y: _rand(0, s.height),
          vx: _rand(-4, 4),
          vy: _rand(-10, -4),
          ax: 0,
          ay: 0,
          life: _rand(1.2, 2.4),
          maxLife: 2.4,
          size: _rand(2, 4),
          phase: _rand(0, math.pi * 2),
          color: c,
        );
    }
  }

  // Integrate one particle forward by dt using its motion rule.
  void _step(_Particle p, Size s, double dt) {
    p.life -= dt;
    switch (_spec.motion) {
      case _Motion.orbit:
        p.angle += p.angVel * dt;
        p.radius -= 6 * dt; // spiral inward
        p.x = s.width / 2 + math.cos(p.angle) * p.radius;
        p.y = s.height / 2 + math.sin(p.angle) * p.radius;
        break;
      case _Motion.fall:
        p.vy += p.ay * dt;
        p.vx += p.ax * dt;
        // Horizontal sway, like a snowflake catching air.
        p.x += p.vx * dt + math.sin(_t * 3 + p.phase) * 8 * dt;
        p.y += p.vy * dt;
        break;
      default:
        p.vy += p.ay * dt;
        p.vx += p.ax * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
    }
  }

  bool _dead(_Particle p, Size s) {
    if (p.life <= 0) return true;
    const m = 8.0;
    if (_spec.motion == _Motion.orbit) return p.radius < 2;
    return p.x < -m || p.x > s.width + m || p.y < -m || p.y > s.height + m;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpace.radiusSm),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _PreviewPainter(
            particles: _particles,
            spec: _spec,
            baseColor: widget.info.color,
            t: _t,
          ),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final List<_Particle> particles;
  final _Spec spec;
  final Color baseColor;
  final double t;
  _PreviewPainter({
    required this.particles,
    required this.spec,
    required this.baseColor,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(AppSpace.radiusSm));
    canvas.clipRRect(rrect);

    // Dark base so glows and sparks read with contrast.
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF10131A));

    // Turf styles render as a claimed land plot with a flag — a clearly
    // different identity from the flowing trail particles.
    if (spec.isTurf) {
      _paintTurfPlot(canvas, size);
      return;
    }

    // Particles: a soft halo + a bright core for a glowing look.
    for (final p in particles) {
      final lifeFrac = (p.life / p.maxLife).clamp(0.0, 1.0);
      final a = (spec.motion == _Motion.fall || spec.motion == _Motion.orbit)
          ? lifeFrac // fade out as they die
          : Curves.easeOut.transform(lifeFrac); // embers/sparks fade near end
      final pos = Offset(p.x, p.y);

      if (spec.motion == _Motion.shoot) {
        // Draw a streak along the velocity for a spark trail.
        final tail = pos - Offset(p.vx, p.vy) * 0.05;
        canvas.drawLine(
          tail,
          pos,
          Paint()
            ..color = p.color.withValues(alpha: 0.9 * a)
            ..strokeWidth = p.size
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      // Halo.
      canvas.drawCircle(
        pos,
        p.size * 2.2,
        Paint()
          ..color = p.color.withValues(alpha: 0.22 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // Core.
      canvas.drawCircle(
        pos,
        p.size * (0.7 + 0.3 * a),
        Paint()..color = p.color.withValues(alpha: 0.95 * a),
      );
    }
  }

  // Draw the claimed-land plot: an inset rounded patch filled per style, a
  // border so it reads as territory, and a planted flag in the player's colour.
  void _paintTurfPlot(Canvas canvas, Size size) {
    final plot = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(7), const Radius.circular(8));
    final plotRect = plot.outerRect;

    canvas.save();
    canvas.clipRRect(plot);
    switch (spec.bg) {
      case _Bg.solid:
        canvas.drawRect(plotRect, Paint()..color = baseColor.withValues(alpha: 0.55));
        // A soft diagonal sheen sweeping across, like light over the land.
        final sx = (t * 0.35 % 1.0) * (plotRect.width + plotRect.height) -
            plotRect.height;
        canvas.drawRect(
          plotRect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ).createShader(Rect.fromLTWH(
                plotRect.left + sx, plotRect.top, 24, plotRect.height)),
        );
        break;
      case _Bg.outline:
        canvas.drawRect(plotRect, Paint()..color = baseColor.withValues(alpha: 0.14));
        break;
      case _Bg.glow:
        final pulse = 0.5 + 0.5 * math.sin(t * 2.4);
        canvas.drawRect(plotRect, Paint()..color = baseColor.withValues(alpha: 0.18));
        canvas.drawRect(
          plotRect,
          Paint()
            ..shader = RadialGradient(colors: [
              baseColor.withValues(alpha: 0.25 + 0.5 * pulse),
              Colors.transparent,
            ]).createShader(plotRect),
        );
        break;
      case _Bg.hatch:
        canvas.drawRect(plotRect, Paint()..color = baseColor.withValues(alpha: 0.16));
        final paint = Paint()
          ..color = baseColor.withValues(alpha: 0.7)
          ..strokeWidth = 3;
        final offset = (t * 10) % 12; // scrolling stripes
        for (double x = plotRect.left - plotRect.height + offset;
            x < plotRect.right;
            x += 12) {
          canvas.drawLine(Offset(x, plotRect.bottom),
              Offset(x + plotRect.height, plotRect.top), paint);
        }
        break;
      case _Bg.none:
        break;
    }
    canvas.restore();

    // Territory border — thicker for the "Bordered" style.
    canvas.drawRRect(
      plot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = spec.bg == _Bg.outline ? 3.5 : 1.6
        ..color = baseColor.withValues(alpha: 0.95),
    );

    _paintFlag(canvas, Offset(size.width / 2, size.height / 2 + 3));
  }

  // A small planted flag so turf clearly reads as "land you own".
  void _paintFlag(Canvas canvas, Offset base) {
    const poleH = 16.0;
    final top = base - const Offset(0, poleH);
    // Pole.
    canvas.drawLine(
      base,
      top,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // Pennant — a little wave via the flag tip following t.
    final wave = math.sin(t * 5) * 1.5;
    final flag = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + 11, top.dy + 3 + wave)
      ..lineTo(top.dx, top.dy + 7)
      ..close();
    canvas.drawPath(flag, Paint()..color = baseColor);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}
