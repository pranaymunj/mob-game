// splash_screen.dart — The app-open cinematic.
//
// This is Claimr's title sequence, and it deliberately tells the game rather
// than showing a generic logo: a city grid resolves out of the dark, a neon
// GPS trail runs the streets, the loop snaps shut, and the enclosed block
// floods with your colour in a shockwave. That is the entire game in four
// seconds — the first thing a new player sees is the thing they're about to do.
//
// It's drawn procedurally (CustomPainter) rather than played from a Lottie/
// video file: it stays razor sharp at any screen size, weighs nothing in the
// bundle, and every beat is tunable in code.
//
// It plays in full on every app open, by product decision — this is the
// game's title card, not a loading screen. It stays skippable from the first
// moments so anyone in a hurry is never trapped.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

// Beat sheet, in normalised time (0..1 of the controller). Keeping every beat
// in one table is what makes the timing tunable without hunting through paint
// code — nudge a number here and the whole sequence re-times around it.
class _Beat {
  static const gridIn = [0.00, 0.16]; // grid resolves out of black
  static const trail = [0.10, 0.50]; // GPS trail draws the loop
  static const snap = [0.48, 0.56]; // loop closes — flash + shake
  static const flood = [0.51, 0.72]; // territory floods with colour
  static const shock = [0.51, 0.78]; // shockwave ring crosses the screen
  static const iconIn = [0.60, 0.74]; // app icon rises
  static const wordIn = [0.66, 0.80]; // wordmark punches in
  static const shine = [0.78, 0.92]; // light sweep across the wordmark
  static const taglineIn = [0.80, 0.90];
  static const fadeOut = [0.94, 1.00];
}

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4400);

  late final AnimationController _c;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Rolls immediately — nothing to load, nothing to wait on, so the very
    // first frame after launch is already the cinematic.
    _c = AnimationController(vsync: this, duration: _duration)
      ..forward().whenComplete(_finish);
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

  // Progress through one beat, eased, clamped outside it.
  double _seg(List<double> beat, {Curve c = Curves.easeOut}) =>
      c.transform(((_c.value - beat[0]) / (beat[1] - beat[0])).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;

          // Camera shake on the capture — damped, so it hits hard then settles.
          final shakeT = _seg(_Beat.snap, c: Curves.linear);
          final shake = shakeT > 0 && shakeT < 1
              ? math.sin(shakeT * math.pi * 7) * 13 * (1 - shakeT)
              : 0.0;

          final fade = 1 - _seg(_Beat.fadeOut, c: Curves.easeIn);

          // How far the map scene has receded behind the brand lockup.
          final settle = _seg(_Beat.iconIn, c: Curves.easeOutCubic);

          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(shake, shake * 0.55),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The cinematic itself. `repaint: _c` drives the painter
                  // directly, so each frame is a paint, not a widget rebuild.
                  // Once the capture lands, the camera pushes in slightly and
                  // the scrim below drops the contrast, so the scene becomes a
                  // backdrop for the logo rather than competing with it.
                  // The push must be *inward* (>1): scaling down would shrink
                  // the canvas away from the screen edges and expose bare
                  // background as a hard-edged rectangle.
                  Transform.scale(
                    // A slow drift across the whole sequence, then a firmer
                    // push once the capture lands. Constant subtle motion is
                    // what separates a title sequence from a static logo.
                    scale: 1.03 + 0.05 * t + 0.09 * settle,
                    child: CustomPaint(
                      painter: _CinematicPainter(
                        repaint: _c,
                        gridIn: _seg(_Beat.gridIn),
                        trail: _seg(_Beat.trail, c: Curves.easeInOutCubic),
                        snap: _seg(_Beat.snap, c: Curves.linear),
                        flood: _seg(_Beat.flood, c: Curves.easeOutCubic),
                        shock: _seg(_Beat.shock, c: Curves.easeOutCubic),
                        time: t,
                      ),
                    ),
                  ),
                  // Scrim: pushes the scene down in contrast right where the
                  // lockup sits, so the wordmark never has to fight the
                  // territory's fill or rim for legibility.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.85,
                          colors: [
                            Colors.black.withValues(alpha: 0.72 * settle),
                            Colors.black.withValues(alpha: 0.18 * settle),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _brandLockup(),
                  _skipButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Icon + wordmark + tagline, revealed after the capture lands.
  Widget _brandLockup() {
    final iconIn = _seg(_Beat.iconIn, c: Curves.easeOutBack);
    final wordIn = _seg(_Beat.wordIn, c: Curves.easeOutBack);
    final shine = _seg(_Beat.shine, c: Curves.easeInOut);
    final taglineIn = _seg(_Beat.taglineIn);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: iconIn.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.55 + 0.45 * iconIn,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.55 * iconIn),
                      blurRadius: 44,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset('assets/app_icon.png',
                      width: 104, height: 104),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Wordmark, with a diagonal light sweep once it has landed.
          ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (shine - 0.18).clamp(0.0, 1.0),
                shine.clamp(0.0, 1.0),
                (shine + 0.18).clamp(0.0, 1.0),
              ],
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white
                    .withValues(alpha: shine > 0 && shine < 1 ? 0.9 : 0.0),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(rect),
            child: Opacity(
              opacity: wordIn.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 26 * (1 - wordIn)),
                child: Text(
                  AppConstants.appName.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: AppColors.accent.withValues(alpha: 0.85),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: taglineIn.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - taglineIn)),
              child: Text(
                'Claim the streets.',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 15,
                  letterSpacing: 3.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skipButton() => Positioned(
        right: 16,
        bottom: 24,
        child: SafeArea(
          child: Opacity(
            opacity: _seg([0.04, 0.12]).clamp(0.0, 1.0),
            child: TextButton(
              onPressed: _finish,
              child: Text(
                'SKIP  ▸',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// The painter: city grid → GPS trail → loop snap → territory flood.
// ─────────────────────────────────────────────────────────────────────────────

class _CinematicPainter extends CustomPainter {
  final double gridIn, trail, snap, flood, shock, time;

  _CinematicPainter({
    required Listenable repaint,
    required this.gridIn,
    required this.trail,
    required this.snap,
    required this.flood,
    required this.shock,
    required this.time,
  }) : super(repaint: repaint);

  // The route, in a normalised 0..1 box. Deliberately blocky with a couple of
  // angled cuts — it should read as "streets", not as a geometric shape.
  // Kept wide enough that the brand lockup sits comfortably *inside* the
  // claimed block — a wordmark clipped by its own territory reads as a bug.
  static const List<Offset> _route = [
    Offset(0.12, 0.74),
    Offset(0.12, 0.52),
    Offset(0.26, 0.52),
    Offset(0.26, 0.30),
    Offset(0.54, 0.30),
    Offset(0.64, 0.22),
    Offset(0.88, 0.22),
    Offset(0.88, 0.48),
    Offset(0.76, 0.60),
    Offset(0.76, 0.74),
    Offset(0.44, 0.74),
    Offset(0.12, 0.74), // closes the loop
  ];

  Path _routePath(Size size) {
    // Inset so the loop never kisses the screen edge on tall or wide devices.
    final box = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.10,
      size.width * 0.88,
      size.height * 0.80,
    );
    Offset at(Offset n) =>
        Offset(box.left + n.dx * box.width, box.top + n.dy * box.height);

    final path = Path()..moveTo(at(_route.first).dx, at(_route.first).dy);
    for (final p in _route.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackdrop(canvas, size);
    _paintGrid(canvas, size);

    final path = _routePath(size);
    final metric = path.computeMetrics().first;
    final closurePoint = metric.getTangentForOffset(0)?.position ??
        Offset(size.width / 2, size.height / 2);

    if (flood > 0) _paintFlood(canvas, size, path, closurePoint);
    if (trail > 0) _paintTrail(canvas, metric);
    if (snap > 0) _paintSnap(canvas, size, closurePoint);
    if (shock > 0) _paintShockwave(canvas, size, closurePoint);
  }

  // Deep vignette so the centre lockup always has contrast to sit on.
  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.background);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          size.longestSide * 0.72,
          [
            AppColors.accent.withValues(alpha: 0.10 * gridIn),
            Colors.black.withValues(alpha: 0.86),
          ],
        ),
    );
  }

  // The city grid, resolving out of the dark with a slow drift — it reads as a
  // map settling into focus rather than a static wallpaper.
  void _paintGrid(Canvas canvas, Size size) {
    if (gridIn <= 0) return;
    final drift = time * 26; // slow parallax across the whole sequence
    final spacing = size.shortestSide / 7.5;

    final thin = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.055 * gridIn)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.11 * gridIn)
      ..strokeWidth = 2;

    var i = 0;
    for (var x = -spacing + (drift % spacing); x < size.width; x += spacing) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), i++ % 3 == 0 ? major : thin);
    }
    i = 0;
    for (var y = -spacing + (drift % spacing); y < size.height; y += spacing) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), i++ % 3 == 0 ? major : thin);
    }
  }

  // The claimed block. Revealed by growing a circular clip out of the closure
  // point, so the colour visibly *floods* the territory from where you sealed
  // it rather than simply fading up.
  void _paintFlood(Canvas canvas, Size size, Path path, Offset from) {
    final radius = flood * size.longestSide * 1.15;
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(center: from, radius: radius)));

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.2),
          Offset(size.width, size.height * 0.8),
          [
            AppColors.accent.withValues(alpha: 0.62),
            AppColors.go.withValues(alpha: 0.42),
          ],
        ),
    );
    // Bright rim on the claimed edge.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.4),
    );
    canvas.restore();
  }

  // The GPS trail drawing itself, with a glowing runner head at the tip.
  void _paintTrail(Canvas canvas, ui.PathMetric metric) {
    final drawn = metric.extractPath(0, metric.length * trail);

    // Wide soft glow underneath, then a hard bright core on top — the two-pass
    // trick that makes a stroke read as neon rather than as a coloured line.
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accent.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.92),
    );

    // The runner head — only while the trail is still being drawn.
    if (trail >= 1) return;
    final head = metric.getTangentForOffset(metric.length * trail)?.position;
    if (head == null) return;

    final pulse = 0.85 + 0.15 * math.sin(time * 40);
    canvas.drawCircle(
      head,
      20 * pulse,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(head, 6.5 * pulse, Paint()..color = Colors.white);
  }

  // The instant the loop seals: a hot flash at the closure point plus a burst
  // of sparks. Deterministic random, so the burst is identical every launch.
  void _paintSnap(Canvas canvas, Size size, Offset at) {
    final fade = 1 - snap;

    canvas.drawCircle(
      at,
      size.shortestSide * (0.10 + 0.5 * snap),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * fade * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 40 + 60 * snap),
    );

    // Spread the burst evenly around the circle (with a little jitter) rather
    // than sampling angles at random — pure random clumps, and a clumped
    // burst reads as a glitch instead of an impact.
    final rng = math.Random(7);
    const count = 34;
    for (var i = 0; i < count; i++) {
      final angle =
          (i / count) * math.pi * 2 + (rng.nextDouble() - 0.5) * 0.35;
      final reach = size.shortestSide * (0.28 + rng.nextDouble() * 0.55);
      final d = reach * Curves.easeOutCubic.transform(snap);
      final p = at + Offset(math.cos(angle) * d, math.sin(angle) * d);
      canvas.drawCircle(
        p,
        (2.0 + rng.nextDouble() * 3.5) * fade,
        Paint()
          ..color = (i.isEven ? Colors.white : AppColors.go)
              .withValues(alpha: fade),
      );
    }
  }

  // A ring pushing out past the screen edge — the "this land is mine" beat.
  void _paintShockwave(Canvas canvas, Size size, Offset from) {
    final fade = 1 - shock;
    canvas.drawCircle(
      from,
      shock * size.longestSide * 0.95,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 10 * fade
        ..color = AppColors.accent.withValues(alpha: 0.75 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _CinematicPainter old) => true;
}
