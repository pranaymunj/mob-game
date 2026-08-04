// splash_screen.dart — Cinematic app-open (~16s), in the spirit of Clash of
// Clans / Clash Royale intros. Phases: a territory grid draws in, "claim"
// ripples flood patches of land in colour, the app icon slams in with a glow,
// the CLAIMR wordmark builds letter-by-letter, a shine sweeps across, and the
// tagline rises — then it fades into the app. A Skip button is always offered.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Mote> _motes;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _motes = List.generate(26, (_) {
      return _Mote(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.03 + rng.nextDouble() * 0.09,
        drift: (rng.nextDouble() - 0.5) * 0.06,
        size: 1.5 + rng.nextDouble() * 3.0,
        phase: rng.nextDouble() * math.pi * 2,
      );
    });

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16000),
    )..forward().whenComplete(_finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Eased sub-interval of the master timeline.
  double _seg(double start, double end, {Curve curve = Curves.easeOut}) {
    final raw = ((_c.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    final word = AppConstants.appName.toUpperCase();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final iconIn = _seg(0.30, 0.45, curve: Curves.elasticOut);
          final iconFade = _seg(0.30, 0.38);
          final glow = 0.5 + 0.5 * math.sin(t * 10); // idle logo shimmer
          final shine = _seg(0.62, 0.76);
          final taglineIn = _seg(0.66, 0.80);
          final fadeOut = 1 - _seg(0.94, 1.0);

          return Opacity(
            opacity: fadeOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cinematic backdrop: grid, ripples, flooding turf, motes.
                CustomPaint(
                  painter: _IntroPainter(t: t, motes: _motes),
                ),
                // Centre stack: icon + wordmark + tagline.
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: iconFade,
                        child: Transform.scale(
                          scale: 0.4 + 0.6 * iconIn,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                      alpha: 0.35 + 0.35 * glow * iconIn),
                                  blurRadius: 34,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.asset('assets/app_icon.png',
                                  width: 120, height: 120),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      // Wordmark builds letter by letter, then a shine sweeps.
                      ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (rect) {
                          final p = shine; // 0..1 sweep position
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [
                              (p - 0.18).clamp(0.0, 1.0),
                              p.clamp(0.0, 1.0),
                              (p + 0.18).clamp(0.0, 1.0),
                            ],
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: shine > 0 && shine < 1 ? 0.9 : 0),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ).createShader(rect);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < word.length; i++)
                              _Letter(
                                ch: word[i],
                                anim: _seg(0.45 + i * 0.025,
                                    0.55 + i * 0.025,
                                    curve: Curves.easeOutBack),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: taglineIn,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - taglineIn)),
                          child: Text(
                            'Claim the streets.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading shimmer + Skip.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: Column(
                    children: [
                      Opacity(
                        opacity: _seg(0.05, 0.15),
                        child: SizedBox(
                          width: 150,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: t,
                              minHeight: 4,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: _seg(0.04, 0.12),
                        child: TextButton(
                          onPressed: _finish,
                          child: Text(
                            'SKIP  ▸',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
}

// A single wordmark letter that pops up into place.
class _Letter extends StatelessWidget {
  final String ch;
  final double anim; // 0..1
  const _Letter({required this.ch, required this.anim});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: anim.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 26 * (1 - anim)),
        child: Text(
          ch,
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
            shadows: [
              Shadow(
                  color: AppColors.accent.withValues(alpha: 0.7),
                  blurRadius: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mote {
  final double x, y, speed, drift, size, phase;
  const _Mote({
    required this.x,
    required this.y,
    required this.speed,
    required this.drift,
    required this.size,
    required this.phase,
  });
}

class _IntroPainter extends CustomPainter {
  final double t; // 0..1 master timeline
  final List<_Mote> motes;
  _IntroPainter({required this.t, required this.motes});

  // Preset land patches (relative rects) that flood colour in sequence.
  static const _patches = <(double, double, double, double, double)>[
    // left, top, w, h, floodStartT
    (0.08, 0.18, 0.28, 0.16, 0.20),
    (0.62, 0.24, 0.26, 0.18, 0.28),
    (0.16, 0.66, 0.30, 0.15, 0.36),
    (0.58, 0.62, 0.30, 0.20, 0.44),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1) Territory grid draws in and stays as a faint backdrop.
    final gridReveal = ((t - 0.03) / 0.17).clamp(0.0, 1.0);
    if (gridReveal > 0) {
      final gp = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.10 * gridReveal)
        ..strokeWidth = 1;
      const step = 38.0;
      for (double x = 0; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
      }
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
      }
    }

    // 2) Land patches flood colour, like turf being claimed on the map.
    for (var i = 0; i < _patches.length; i++) {
      final (l, top, w, h, start) = _patches[i];
      final flood = ((t - start) / 0.09).clamp(0.0, 1.0);
      if (flood <= 0) continue;
      final color = AppColors.ownershipPalette[i % AppColors.ownershipPalette.length];
      final rect = Rect.fromLTWH(
          l * size.width, top * size.height, w * size.width, h * size.height);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(
          rr, Paint()..color = color.withValues(alpha: 0.16 * flood));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.6 * flood),
      );
    }

    // 3) Expanding "claim" ripples from the centre.
    for (final start in const [0.15, 0.30, 0.45]) {
      final p = ((t - start) / 0.22).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final maxR = size.shortestSide * 0.7;
      canvas.drawCircle(
        center,
        maxR * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - p)
          ..color = AppColors.accent.withValues(alpha: 0.5 * (1 - p)),
      );
    }

    // 4) Ambient motes rising through the whole sequence.
    if (t > 0.08) {
      for (final m in motes) {
        final yy = (m.y - m.speed * t * 3) % 1.0;
        final xx = (m.x + math.sin(t * 6 + m.phase) * m.drift) % 1.0;
        final a = 0.35 * (t > 0.9 ? (1 - t) / 0.1 : 1).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(xx * size.width, yy * size.height),
          m.size,
          Paint()..color = AppColors.accent.withValues(alpha: a),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IntroPainter old) => old.t != t;
}
