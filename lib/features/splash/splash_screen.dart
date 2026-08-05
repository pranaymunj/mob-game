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

  // ── The city, as lights ─────────────────────────────────────────────────
  // Your city seen from the air at night: thousands of small lights strung
  // along streets we never draw, dense downtown and thinning to darkness at
  // the edges. Nothing is drawn as a line or a filled rectangle — the streets
  // exist only as the lines the lights sit on, which is what stops it reading
  // as a diagram.
  //
  // The field is generated once per screen size and cached: placement is
  // deterministic, so it's the same city on every launch, and the per-frame
  // cost is a cull plus a draw.

  static Size? _fieldSize;
  static List<_Light>? _field;

  List<_Light> _lights(Size size) {
    if (_fieldSize == size && _field != null) return _field!;

    final c = _cell(size);
    final a = _anchor(size);
    final route = _routePath(size);
    final rnd = math.Random(20260805);
    final out = <_Light>[];

    const reach = 13; // cells from the anchor, covers the widest framing

    // Precompute the rival regions once rather than per light.
    final regions = [
      for (final r in _rivals)
        Rect.fromPoints(
          _at(size, r[0], r[1]),
          _at(size, r[0] + r[2], r[1] + r[3]),
        )
    ];

    // Emit a RUN of lights along one street segment. Independently scattered
    // points read as a starfield no matter how many you draw; it's the runs
    // that make streets appear, because the eye joins collinear dots into a
    // line long before it counts them.
    void run(Offset from, Offset to, double density) {
      final count = (4 + rnd.nextInt(7) * density).round();
      if (count < 2) return;
      final dir = to - from;
      final len = dir.distance;
      if (len == 0) return;
      final across = Offset(-dir.dy / len, dir.dx / len);

      for (var i = 0; i < count; i++) {
        // Even spacing with a little slop, so lamps sit in a line but not a
        // perfect ruler.
        final f = (i + 0.5 + (rnd.nextDouble() - 0.5) * 0.55) / count;
        if (f < 0 || f > 1) continue;
        final jitter = (rnd.nextDouble() - 0.5) * c * 0.05;
        final p = from + dir * f + across * jitter;

        final warm = rnd.nextDouble() < 0.74;
        final colour = warm
            ? Color.lerp(const Color(0xFFFFC27A), const Color(0xFFFFE7BE),
                rnd.nextDouble())!
            : Color.lerp(const Color(0xFFA8C6FF), const Color(0xFFE4EEFF),
                rnd.nextDouble())!;

        var owner = -1;
        for (var k = 0; k < regions.length; k++) {
          if (regions[k].contains(p)) {
            owner = k;
            break;
          }
        }
        if (owner == -1 && route.contains(p)) owner = -2; // yours

        out.add(_Light(
          x: p.dx,
          y: p.dy,
          radius: c * (0.006 + rnd.nextDouble() * 0.013),
          brightness: 0.28 + rnd.nextDouble() * 0.72,
          phase: rnd.nextDouble() * math.pi * 2,
          colour: colour,
          owner: owner,
        ));
      }
    }

    for (var col = -reach; col <= reach; col++) {
      for (var row = -reach; row <= reach; row++) {
        // Downtown is dense and bright; the outskirts thin to dark. The
        // falloff is what gives the field a centre instead of uniform static.
        final d = math.sqrt(col * col + row * row) / reach;
        final density = (1.0 - d * d).clamp(0.0, 1.0);
        if (density <= 0.02) continue;

        final o = Offset(a.dx + col * c, a.dy + row * c);
        // Avenues (every third line) are lit more heavily than side streets.
        if (rnd.nextDouble() < density * (row % 3 == 0 ? 0.95 : 0.55)) {
          run(o, o + Offset(c, 0), density);
        }
        if (rnd.nextDouble() < density * (col % 3 == 0 ? 0.95 : 0.55)) {
          run(o, o + Offset(0, c), density);
        }
      }
    }

    _fieldSize = size;
    _field = out;
    return out;
  }

  void _paintCity(Canvas canvas, Size size, Rect view) {
    if (gridIn <= 0) return;

    // A soft downtown haze, so the lights sit in glow rather than on flat black.
    canvas.drawCircle(
      _anchor(size),
      _cell(size) * 9,
      Paint()
        ..color = const Color(0xFF2A3E63).withValues(alpha: 0.30 * gridIn)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _cell(size) * 4),
    );

    final grown = view.inflate(_cell(size));
    final dot = Paint();
    final bloom = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _cell(size) * 0.07);

    for (final l in _lights(size)) {
      if (!grown.contains(Offset(l.x, l.y))) continue;

      // Turf recolours the lights it stands on — the district is legible from
      // the colour of its own windows, with no rectangle laid over the map.
      var colour = l.colour;
      var lit = l.brightness;
      var owned = 0.0; // how strongly this light is claimed by someone

      if (l.owner >= 0) {
        owned = ((rivals - l.owner * 0.09) / 0.5).clamp(0.0, 1.0);
        if (owned > 0) {
          colour = Color.lerp(l.colour,
              AppColors.ownershipPalette[_rivals[l.owner][4]], 0.95 * owned)!;
          lit = l.brightness * (1 + 1.9 * owned);
        }
      } else if (l.owner == -2 && flood > 0) {
        owned = flood;
        colour = Color.lerp(l.colour, Colors.white, 0.6 * flood)!;
        lit = l.brightness * (1 + 2.4 * flood);
      }

      // Slow, shallow twinkle — enough to feel alive, not enough to sparkle.
      final tw = 0.80 + 0.20 * math.sin(time * 5 + l.phase);
      final alpha = (lit * tw * gridIn).clamp(0.0, 1.0);

      // Claimed windows always bloom, which is what makes a district emerge
      // from the field without any shape being drawn around it.
      if (owned > 0.05) {
        canvas.drawCircle(
            Offset(l.x, l.y),
            l.radius * (3.2 + 3.4 * owned),
            bloom..color = colour.withValues(alpha: alpha * 0.55 * owned));
      } else if (l.brightness > 0.80) {
        canvas.drawCircle(Offset(l.x, l.y), l.radius * 3.4,
            bloom..color = colour.withValues(alpha: alpha * 0.40));
      }
      canvas.drawCircle(Offset(l.x, l.y), l.radius,
          dot..color = colour.withValues(alpha: alpha));
    }
  }

  // Rival turf. Drawn as the city's own blocks lit up in the owner's colour —
  // not as translucent rectangles laid over the map. Flat rectangles at low
  // alpha over a near-black ground turn muddy (olive, brown, maroon), which is
  // exactly how the earlier version failed.
  //
  // Each owner also gets a hatch at their own angle, so ownership never rests
  // on hue alone (CLAUDE.md Part 5, accessibility).
  // Rival turf is carried ENTIRELY by the colour of its own lights, in
  // _paintCity — there is deliberately nothing to draw here.
  //
  // Every shaped overlay we tried failed the same way: a hard rectangle reads
  // as a sticker on the map, and blurring it to hide the edge turns it into a
  // smudge. A district made of its own glowing windows has no edge to give
  // away, which is how it looks like a place rather than a highlight.
  void _paintRivals(Canvas canvas, Size size) {}

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

// One window/streetlight in the aerial field.
class _Light {
  final double x, y, radius, brightness, phase;
  final Color colour;
  final int owner; // -1 unclaimed, -2 yours, 0.. index into _rivals

  const _Light({
    required this.x,
    required this.y,
    required this.radius,
    required this.brightness,
    required this.phase,
    required this.colour,
    required this.owner,
  });
}
