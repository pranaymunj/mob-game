// splash_screen.dart — The app-open cinematic ("City Reveal").
//
// Claimr's title sequence, built to say what the game is before a single tap:
// we open tight on your runner in the dark, the camera pulls back over the
// city while a GPS trail draws itself, the loop snaps shut, the enclosed block
// floods with your colour, and a flag plants on the corner you sealed.
//
// Three ideas carry it, and each one fixes something that read as amateur:
//
//  1. The route is defined in GRID CELLS, not free coordinates, so the trail
//     turns on a consistent lattice instead of wandering. A path that ignores
//     the geometry it sits on is the single biggest tell of a fake map.
//  2. A real camera (translate + scale inside the painter) pulls back from the
//     runner to the city. Camera scale never drops below 1, so the canvas can
//     never shrink away from the screen edges and expose bare background.
//  3. The backdrop is a real aerial photograph of a city at night, held well
//     back — dimmed and tinted — because its streets are not our streets, and
//     a bright one would advertise the mismatch (assets/images/CREDITS.md).
//
// Everything except that photograph is drawn in code rather than played from a
// Lottie or video: sharp at any size, and every beat tunable from the table
// below.
//
// Plays in full on every app open, by product decision — this is the game's
// title card, not a loading screen. Skippable from the first moments.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants.dart';
import '../../core/theme.dart';

// Beat sheet, in normalised time (0..1). Keeping every beat in one table is
// what makes the sequence tunable — nudge a number and the rest re-times
// around it, without hunting through paint code.
class _Beat {
  static const gridIn = [0.00, 0.10]; // streets resolve out of black
  static const pullback = [0.00, 0.56]; // camera retreats from runner to city
  static const trail = [0.08, 0.50]; // GPS trail runs the streets
  static const snap = [0.48, 0.56]; // loop closes — flash, sparks, shake
  static const flood = [0.51, 0.72]; // your block floods with colour
  static const shock = [0.51, 0.80]; // shockwave crosses the city
  static const flag = [0.54, 0.70]; // flag plants on the claimed corner
  static const iconIn = [0.62, 0.76];
  static const wordIn = [0.68, 0.82];
  static const shine = [0.80, 0.94]; // light sweep across the wordmark
  static const taglineIn = [0.82, 0.92];
  static const fadeOut = [0.95, 1.00];
}

// How far into the flag beat the pole actually strikes the ground. Shared,
// because the screen shake and the painter both key off the same instant —
// if they drifted apart the knock would land before or after the impact.
const double _flagDrop = 0.42;

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
  ui.Image? _backdrop;

  @override
  void initState() {
    super.initState();
    // Rolls immediately — the cinematic never waits on the photo. The opening
    // beat is near-black anyway, so the backdrop fading in a frame or two late
    // is invisible, and a slow decode can never delay the app opening.
    _c = AnimationController(vsync: this, duration: _duration)
      ..forward().whenComplete(_finish);
    _loadBackdrop();
  }

  Future<void> _loadBackdrop() async {
    try {
      final data = await rootBundle.load('assets/images/night_city.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _backdrop = frame.image);
    } catch (_) {
      // No photo: the cinematic still plays over the dark ground.
    }
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

          // A second, much smaller knock when the flag drives into the ground.
          // Two impacts of the same size would read as one long rumble; this
          // one has to feel like a tap after a bang.
          final flagT = _seg(_Beat.flag, c: Curves.linear);
          final plant = ((flagT - _flagDrop) / 0.20).clamp(0.0, 1.0);
          final plantShake = plant > 0 && plant < 1
              ? math.sin(plant * math.pi * 5) * 3.5 * (1 - plant)
              : 0.0;

          final fade = 1 - _seg(_Beat.fadeOut, c: Curves.easeIn);

          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(shake, shake * 0.5 + plantShake),
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
                      snap: _seg(_Beat.snap, c: Curves.linear),
                      flood: _seg(_Beat.flood, c: Curves.easeOutCubic),
                      shock: _seg(_Beat.shock, c: Curves.easeOutCubic),
                      // Linear: the flag stages its own fall, impact, settle
                      // and unfurl internally, so a curve here would fight it.
                      flag: _seg(_Beat.flag, c: Curves.linear),
                      push: _seg(_Beat.iconIn, c: Curves.easeOutCubic),
                      backdrop: _backdrop,
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
  final double gridIn, pull, trail, snap, flood, shock, flag, push, time;
  final ui.Image? backdrop;

  _CityPainter({
    required Listenable repaint,
    required this.gridIn,
    required this.pull,
    required this.trail,
    required this.snap,
    required this.flood,
    required this.shock,
    required this.flag,
    required this.push,
    required this.backdrop,
    required this.time,
  }) : super(repaint: repaint);

  // Your route, in whole city blocks from the anchor. Rectilinear with one
  // diagonal cut — it should read as a walkable circuit of real streets.
  static const List<List<int>> _route = [
    [-2, 2], [-2, -1], [0, -1], [0, -3], [2, -3],
    [3, -2], [3, 0], [1, 0], [1, 2], [-2, 2], // closes
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

    // Only build the blocks the camera can actually see — at the widest
    // framing that is a few hundred, but drawing the whole lattice every
    // frame would be thousands.
    final view = Rect.fromLTRB(
      focus.dx - centre.dx / cam,
      focus.dy - centre.dy / cam,
      focus.dx + centre.dx / cam,
      focus.dy + centre.dy / cam,
    );

    _paintCity(canvas, size, view);
    if (flood > 0) _paintClaim(canvas, size, path, start);
    if (trail > 0) _paintTrail(canvas, metric);
    if (snap > 0) _paintSnap(canvas, size, start);
    if (shock > 0) _paintShockwave(canvas, size, start);
    if (flag > 0) _paintFlag(canvas, size, start);

    canvas.restore();

    _paintVignette(canvas, size);
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
  }

  // ── Backdrop ────────────────────────────────────────────────────────────
  // A real aerial photograph of a city at night (see assets/images/CREDITS.md)
  // rather than anything procedural.
  //
  // It is deliberately pushed well back — darkened, desaturated and dimmed —
  // because a photograph's streets do not line up with our route, and a bright
  // one would advertise that mismatch. Held down like this it works as
  // atmosphere, and the trail reads as an overlay drawn on top of the city
  // rather than as a path pretending to follow those particular roads.
  void _paintCity(Canvas canvas, Size size, Rect view) {
    if (backdrop == null || gridIn <= 0) return;

    final img = backdrop!;
    final src =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // Cover the world generously, so the widest camera framing still lands on
    // photograph rather than running off its edge.
    final dst = Rect.fromCenter(
      center: _anchor(size),
      width: size.width * 2.6,
      height: size.height * 2.6,
    );

    canvas.saveLayer(dst, Paint());
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: 0.34 * gridIn),
    );
    // Cool the photo toward the app's palette so it does not read as a stock
    // picture bolted onto a blue-and-green game.
    canvas.drawRect(
      dst,
      Paint()
        ..blendMode = BlendMode.color
        ..color = const Color(0xFF2E4B7A),
    );
    canvas.restore();
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
          // Translucent enough that the city's own lights still burn through
          // the claim — the block should read as lit up, not painted over.
          [
            AppColors.accent.withValues(alpha: 0.52),
            AppColors.accentDeep.withValues(alpha: 0.44),
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

  // The flag planted on the corner where the loop was sealed — the beat that
  // turns "a shape got filled in" into "this ground is mine".
  //
  // Staged rather than eased as one curve, because a plant is four distinct
  // events and a single curve blurs them into a glide:
  //   fall    — accelerates downward under gravity (easeIn, not easeOut)
  //   impact  — a dust ring punches outward at the moment of contact
  //   settle  — the pole rings out with a damped oscillation
  //   unfurl  — the cloth catches, overshoots, then flutters
  //
  // The base sits exactly on the closure vertex, so it is planted on the
  // corner rather than floating near it.
  void _paintFlag(Canvas canvas, Size size, Offset corner) {
    final c = _cell(size);
    final f = flag.clamp(0.0, 1.0);
    final poleH = c * 0.95;

    // Stand just inside the corner. Exactly on the vertex the pole falls on
    // the claim's white rim and disappears into it; a quarter-block in, it
    // still reads as marking that corner but has ground of its own.
    final at = corner + Offset(c * 0.24, -c * 0.24);

    // ── fall ────────────────────────────────────────────────────────────────
    final drop = (f / _flagDrop).clamp(0.0, 1.0);
    final falling = drop < 1.0;
    // Gravity accelerates; easeOut here would make it float down like litter.
    final fallen = Curves.easeInCubic.transform(drop);
    final dropOffset = falling ? -(1 - fallen) * poleH * 2.6 : 0.0;

    // ── settle ──────────────────────────────────────────────────────────────
    final since = ((f - _flagDrop) / (1 - _flagDrop)).clamp(0.0, 1.0);
    final ring = falling
        ? 0.0
        : math.sin(since * math.pi * 5) * math.exp(-since * 6) * c * 0.05;

    final baseY = at.dy + dropOffset;
    final topY = baseY - poleH + ring;

    // ── impact ──────────────────────────────────────────────────────────────
    if (!falling) {
      final burst = (since / 0.30).clamp(0.0, 1.0);
      if (burst < 1) {
        canvas.drawCircle(
          Offset(at.dx, at.dy),
          c * (0.05 + 0.34 * Curves.easeOutCubic.transform(burst)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = c * 0.022 * (1 - burst)
            ..color = Colors.white.withValues(alpha: 0.6 * (1 - burst)),
        );
      }
    }

    // Shadow pools only once it is actually down.
    if (!falling) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(at.dx, at.dy), width: c * 0.26, height: c * 0.075),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, c * 0.03),
      );
    }

    // Pole: dark core then bright, so it stays legible on the bright claim
    // fill and on the dark city alike.
    canvas.drawLine(
      Offset(at.dx, baseY),
      Offset(at.dx, topY),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..strokeWidth = c * 0.050
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(at.dx, baseY),
      Offset(at.dx, topY),
      Paint()
        ..color = Colors.white
        ..strokeWidth = c * 0.026
        ..strokeCap = StrokeCap.round,
    );

    // ── unfurl ──────────────────────────────────────────────────────────────
    final unfurl =
        Curves.easeOutBack.transform(((since - 0.10) / 0.55).clamp(0.0, 1.0));
    if (unfurl > 0) {
      final w = c * 0.46 * unfurl.clamp(0.0, 1.12);
      final h = c * 0.29;
      // Snaps taut, then relaxes into a slow idle flutter.
      final energy = math.exp(-since * 3.2);
      final wave = math.sin(time * 9 - 1.2) * c * (0.012 + 0.030 * energy);

      final cloth = Path()
        ..moveTo(at.dx, topY)
        ..quadraticBezierTo(
            at.dx + w * 0.55, topY - h * 0.16 + wave, at.dx + w, topY + wave)
        ..quadraticBezierTo(
            at.dx + w * 0.55, topY + h * 0.46 - wave, at.dx, topY + h * 0.66)
        ..close();

      canvas.drawPath(
        cloth,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(at.dx, topY),
            Offset(at.dx + w, topY + h),
            [AppColors.go, AppColors.goDeep],
          ),
      );
      canvas.drawPath(
        cloth,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = c * 0.014
          ..color = Colors.white.withValues(alpha: 0.8),
      );
    }

    // Finial.
    canvas.drawCircle(
      Offset(at.dx, topY),
      c * 0.085,
      Paint()
        ..color = AppColors.go.withValues(alpha: 0.65 * f)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, c * 0.07),
    );
    canvas.drawCircle(
        Offset(at.dx, topY), c * 0.030, Paint()..color = Colors.white);
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

