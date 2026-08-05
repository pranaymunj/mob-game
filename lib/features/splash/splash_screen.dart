// splash_screen.dart — The app-open cinematic ("City Reveal").
//
// Claimr's title sequence, built to say what the game is before a single tap:
// we open tight on your runner in the dark, the camera pulls back while a GPS
// trail draws itself *along the streets*, rival territory fades up across the
// city as the view widens, and your loop snaps shut — flooding the enclosed
// block with your colour.
//
// Three ideas carry it, and each one fixes something that reads as amateur:
//
//  1. The route is defined in GRID CELLS, not free coordinates, so the trail
//     lands exactly on the street lines. A path that ignores the streets it's
//     drawn over is the single biggest tell of a fake map.
//  2. A real camera (translate + scale inside the painter) pulls back from the
//     runner to the city. Camera scale never drops below 1, so the canvas can
//     never shrink away from the screen edges and expose bare background.
//  3. Rivals already own turf when you arrive, drawn in the colourblind-safe
//     ownership palette — the world is contested before you claim anything.
//
// Drawn procedurally rather than played from a Lottie/video: sharp at any
// size, nothing in the bundle, every beat tunable from the table below.
//
// Plays in full on every app open, by product decision — this is the game's
// title card, not a loading screen. Skippable from the first moments.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

// Beat sheet, in normalised time (0..1). Keeping every beat in one table is
// what makes the sequence tunable — nudge a number and the rest re-times
// around it, without hunting through paint code.
class _Beat {
  static const gridIn = [0.00, 0.10]; // streets resolve out of black
  static const pullback = [0.00, 0.56]; // camera retreats from runner to city
  static const trail = [0.08, 0.50]; // GPS trail runs the streets
  static const rivals = [0.16, 0.52]; // rival turf fades up as the view widens
  static const snap = [0.48, 0.56]; // loop closes — flash, sparks, shake
  static const flood = [0.51, 0.72]; // your block floods with colour
  static const shock = [0.51, 0.80]; // shockwave crosses the city
  static const iconIn = [0.62, 0.76];
  static const wordIn = [0.68, 0.82];
  static const shine = [0.80, 0.94]; // light sweep across the wordmark
  static const taglineIn = [0.82, 0.92];
  static const fadeOut = [0.95, 1.00];
}

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4600);

  late final AnimationController _c;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Rolls immediately — nothing to load, nothing to await, so the first
    // frame after launch is already the cinematic.
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

  double _seg(List<double> beat, {Curve c = Curves.easeOut}) =>
      c.transform(((_c.value - beat[0]) / (beat[1] - beat[0])).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Capture shake — damped, so it hits hard and settles fast.
          final shakeT = _seg(_Beat.snap, c: Curves.linear);
          final shake = shakeT > 0 && shakeT < 1
              ? math.sin(shakeT * math.pi * 7) * 12 * (1 - shakeT)
              : 0.0;

          final fade = 1 - _seg(_Beat.fadeOut, c: Curves.easeIn);

          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(shake, shake * 0.5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // `repaint: _c` drives the painter directly — each frame is
                  // a paint, not a widget rebuild.
                  CustomPaint(
                    painter: _CityPainter(
                      repaint: _c,
                      gridIn: _seg(_Beat.gridIn),
                      pull: _seg(_Beat.pullback, c: Curves.easeInOutCubic),
                      trail: _seg(_Beat.trail, c: Curves.easeInOutCubic),
                      rivals: _seg(_Beat.rivals),
                      snap: _seg(_Beat.snap, c: Curves.linear),
                      flood: _seg(_Beat.flood, c: Curves.easeOutCubic),
                      shock: _seg(_Beat.shock, c: Curves.easeOutCubic),
                      push: _seg(_Beat.iconIn, c: Curves.easeOutCubic),
                      time: _c.value,
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

  // The lockup lives in its own band at the bottom, clear of the claimed
  // block up top. Giving it dedicated space beats dimming the art behind it.
  Widget _brandLockup() {
    final iconIn = _seg(_Beat.iconIn, c: Curves.easeOutBack);
    final wordIn = _seg(_Beat.wordIn, c: Curves.easeOutBack);
    final shine = _seg(_Beat.shine, c: Curves.easeInOut);
    final taglineIn = _seg(_Beat.taglineIn);

    return Align(
      alignment: const Alignment(0, 0.68),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: iconIn.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + 0.4 * iconIn,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.5 * iconIn),
                      blurRadius: 40,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/app_icon.png',
                      width: 88, height: 88),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                offset: Offset(0, 24 * (1 - wordIn)),
                child: Text(
                  AppConstants.appName.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 50,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: AppColors.accent.withValues(alpha: 0.9),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: taglineIn.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - taglineIn)),
              child: Text(
                'Claim the streets.',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
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
        bottom: 20,
        child: SafeArea(
          child: Opacity(
            opacity: _seg([0.04, 0.12]).clamp(0.0, 1.0),
            child: TextButton(
              onPressed: _finish,
              child: Text(
                'SKIP  ▸',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  color: Colors.white.withValues(alpha: 0.45),
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
// The painter. Everything below works in CELL coordinates — integer steps of
// one city block from a fixed anchor — so streets, your route and rival turf
// all land on the same lattice by construction, never by eyeballed numbers.
// ─────────────────────────────────────────────────────────────────────────────

class _CityPainter extends CustomPainter {
  final double gridIn, pull, trail, rivals, snap, flood, shock, push, time;

  _CityPainter({
    required Listenable repaint,
    required this.gridIn,
    required this.pull,
    required this.trail,
    required this.rivals,
    required this.snap,
    required this.flood,
    required this.shock,
    required this.push,
    required this.time,
  }) : super(repaint: repaint);

  // Your route, in whole city blocks from the anchor. Rectilinear with one
  // diagonal cut — it should read as a walkable circuit of real streets.
  static const List<List<int>> _route = [
    [-2, 2], [-2, -1], [0, -1], [0, -3], [2, -3],
    [3, -2], [3, 0], [1, 0], [1, 2], [-2, 2], // closes
  ];

  // Rival turf: [col, row, widthCells, heightCells, paletteIndex]. Placed
  // outside your block so the reveal shows a contested city, not a collision.
  // Kept inside the resting camera's field (roughly cols -4..5, rows -10..9)
  // and clear of your own block (cols -2..3, rows -3..2) — turf you can see is
  // the whole point of drawing it.
  // Rows chosen so nothing is sliced by the top edge or hidden behind the
  // lockup band at the bottom; columns keep clear of the block (cols -2..3)
  // while sitting flush against it, the way real adjacent plots would.
  static const List<List<int>> _rivals = [
    [-4, -7, 2, 2, 0],
    [2, -7, 2, 2, 2],
    [-4, -1, 2, 3, 5],
    [4, -1, 2, 3, 1],
    [-4, 5, 2, 2, 3],
    [2, 5, 2, 3, 6],
  ];

  // Block size sets the final framing: at rest the camera shows about ±5.5
  // blocks horizontally, so the route (5 wide) sits centred with a clear
  // margin of rival turf either side. Bigger cells and the city overflows.
  double _cell(Size size) => size.width / 11.0;

  // Offset by half a cell so the route — which spans cols -2..3 and rows
  // -3..2 — ends up optically centred rather than hanging off to one side.
  Offset _anchor(Size size) {
    final c = _cell(size);
    return Offset(size.width * 0.5 - c * 0.5, size.height * 0.34 + c * 0.5);
  }

  Offset _at(Size size, num col, num row) {
    final c = _cell(size);
    final a = _anchor(size);
    return Offset(a.dx + col * c, a.dy + row * c);
  }

  Path _routePath(Size size) {
    final path = Path();
    for (var i = 0; i < _route.length; i++) {
      final p = _at(size, _route[i][0], _route[i][1]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackdrop(canvas, size);

    final path = _routePath(size);
    final metric = path.computeMetrics().first;
    final start = metric.getTangentForOffset(0)!.position;
    final centre = Offset(size.width / 2, size.height / 2);

    // ── Camera ──────────────────────────────────────────────────────────────
    // Opens tight on the runner, retreats to the whole city, then pushes in a
    // touch as the logo lands. Scale stays >= 1 at all times: a camera that
    // zooms past 1 would shrink the drawing away from the screen edges and
    // expose bare background as a hard-edged rectangle.
    final cam = (2.5 - 1.5 * pull) + 0.05 * push;
    final focus = Offset.lerp(start, centre, pull)!;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(cam);
    canvas.translate(-focus.dx, -focus.dy);

    // World is drawn in a margin wide enough that the retreating camera never
    // runs out of city to show.
    _paintStreets(canvas, size);
    if (rivals > 0) _paintRivals(canvas, size);
    if (flood > 0) _paintClaim(canvas, size, path, start);
    if (trail > 0) _paintTrail(canvas, metric);
    if (snap > 0) _paintSnap(canvas, size, start);
    if (shock > 0) _paintShockwave(canvas, size, start);

    canvas.restore();

    _paintVignette(canvas, size);
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
  }

  // Two-tier street network: avenues every third block read heavier than the
  // minor streets between them. A single uniform lattice looks like graph
  // paper; the tiering is what makes it read as a city.
  void _paintStreets(Canvas canvas, Size size) {
    if (gridIn <= 0) return;
    final c = _cell(size);
    final a = _anchor(size);

    final street = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.10 * gridIn)
      ..strokeWidth = 1.0 / 1.5;
    final avenue = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.22 * gridIn)
      ..strokeWidth = 2.5 / 1.5;

    // Range covers the widest camera framing with room to spare.
    const k = 26;
    final far = c * k;
    for (var i = -k; i <= k; i++) {
      final p = i % 3 == 0 ? avenue : street;
      canvas.drawLine(
          Offset(a.dx + i * c, a.dy - far), Offset(a.dx + i * c, a.dy + far), p);
      canvas.drawLine(
          Offset(a.dx - far, a.dy + i * c), Offset(a.dx + far, a.dy + i * c), p);
    }
  }

  // Rival turf, in the colourblind-safe ownership palette. They fade up in a
  // stagger as the camera widens, so the city fills in rather than popping.
  void _paintRivals(Canvas canvas, Size size) {
    for (var i = 0; i < _rivals.length; i++) {
      final r = _rivals[i];
      // Stagger: each plot starts a little after the one before.
      final t = ((rivals - i * 0.09) / 0.5).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final colour = AppColors.ownershipPalette[r[4]];
      final rect = Rect.fromPoints(
        _at(size, r[0], r[1]),
        _at(size, r[0] + r[2], r[1] + r[3]),
      );

      canvas.drawRect(
        rect,
        Paint()..color = colour.withValues(alpha: 0.20 * t),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / 1.5
          ..color = colour.withValues(alpha: 0.55 * t),
      );
    }
  }

  // Your block. Revealed by growing a circular clip out of the closure point,
  // so the colour visibly floods the territory from where you sealed it.
  void _paintClaim(Canvas canvas, Size size, Path path, Offset from) {
    final radius = flood * size.longestSide * 1.4;
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: from, radius: radius)));

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          _at(size, -3, -4),
          _at(size, 3, 3),
          // Blue-dominant: mixing far into the green made it read as a muddy
          // teal rather than as the player's own colour.
          [
            AppColors.accent.withValues(alpha: 0.72),
            AppColors.accentDeep.withValues(alpha: 0.62),
          ],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 / 1.5
        ..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.restore();
  }

  // The trail drawing itself, with a glowing runner head at the tip.
  void _paintTrail(Canvas canvas, ui.PathMetric metric) {
    final drawn = metric.extractPath(0, metric.length * trail);

    // Wide soft glow, then a hard bright core: the two-pass stroke that makes
    // a line read as neon rather than as a coloured stroke.
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13 / 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accent.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 / 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.95),
    );

    if (trail >= 1) return;
    final head = metric.getTangentForOffset(metric.length * trail)?.position;
    if (head == null) return;

    final pulse = 0.85 + 0.15 * math.sin(time * 42);
    canvas.drawCircle(
      head,
      16 * pulse,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(head, 5.0 * pulse, Paint()..color = Colors.white);
  }

  // The instant the loop seals: hot flash plus a ring of sparks. Angles are
  // spread evenly with jitter — sampling them at random clumps, and a clumped
  // burst reads as a glitch rather than an impact.
  void _paintSnap(Canvas canvas, Size size, Offset at) {
    final fade = 1 - snap;

    canvas.drawCircle(
      at,
      size.shortestSide * (0.08 + 0.34 * snap),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * fade * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 + 50 * snap),
    );

    final rng = math.Random(11);
    const count = 30;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (rng.nextDouble() - 0.5) * 0.3;
      final reach = size.shortestSide * (0.16 + rng.nextDouble() * 0.3);
      final d = reach * Curves.easeOutCubic.transform(snap);
      final p = at + Offset(math.cos(angle) * d, math.sin(angle) * d);
      canvas.drawCircle(
        p,
        (1.6 + rng.nextDouble() * 2.4) * fade,
        Paint()
          ..color =
              (i.isEven ? Colors.white : AppColors.go).withValues(alpha: fade),
      );
    }
  }

  void _paintShockwave(Canvas canvas, Size size, Offset from) {
    final fade = 1 - shock;
    canvas.drawCircle(
      from,
      shock * size.longestSide * 1.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.5 + 9 * fade) / 1.5
        ..color = AppColors.accent.withValues(alpha: 0.7 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  // Drawn outside the camera transform so the framing stays put: darkens the
  // corners and the lower band, keeping the lockup on clean ground.
  void _paintVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.42),
          size.longestSide * 0.62,
          [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.52),
          Offset(0, size.height),
          [Colors.transparent, Colors.black.withValues(alpha: 0.72 * push)],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _CityPainter old) => true;
}
