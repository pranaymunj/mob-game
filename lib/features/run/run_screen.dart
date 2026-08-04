// run_screen.dart — Active gameplay run. Phase 2: shows the live map with a
// colored trail that grows behind your dot as you move, plus Start/Stop.
// Loop capture arrives in Phase 3.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../models/pickup.dart';
import '../../services/geocoding_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../perks/perk_info.dart';
import '../shop/cosmetics_catalog.dart';
import 'capture_celebration.dart';
import 'run_controller.dart';
import 'run_state.dart';
import 'run_summary_screen.dart';

class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen>
    with TickerProviderStateMixin {
  // A short, decaying shake of the whole screen when turf is claimed — the
  // physical "impact" that makes the capture feel like it hit.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _mapReady = false;
  double? _lng, _lat;
  RealtimeChannel? _turfChannel;
  List<List<double>> _ghostPath = const [];
  Timer? _ghostTimer;
  bool _ghostPlaying = false;
  List<Pickup> _pickups = const [];
  bool _collecting = false; // guards against double-collect on rapid points
  int _treasuresShown = 0; // distance milestones celebrated this run
  Widget? _celebration; // the big capture payoff overlay, when playing
  Timer? _ticker; // 1s tick to keep the live elapsed-time readout moving

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(runControllerProvider).isActive) setState(() {});
    });
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    final mapService = ref.read(mapServiceProvider);
    final location = ref.read(locationServiceProvider);

    await mapService.attach(map);
    _mapReady = true;

    final here = await location.current();
    if (here != null) {
      _lng = here.lng;
      _lat = here.lat;
      await mapService.centerOn(lng: here.lng, lat: here.lat);
      await _applyEquippedTrail();
      await _loadTurf();
      await _loadGhost();
      await _loadPickups();
      _subscribeRealtime();
    }
  }

  // Load everyone's persisted turf (owner colors) around the viewport.
  Future<void> _loadTurf() async {
    if (!ref.read(backendEnabledProvider) || _lng == null) return;
    final backend = ref.read(backendServiceProvider);
    await backend.signIn();
    final turf =
        await backend.turfNear(lng: _lng!, lat: _lat!, radiusMeters: 2000);
    await ref.read(mapServiceProvider).drawTurf(turf);
  }

  // Paint the trail (and fresh claims) in the player's equipped trail skin.
  Future<void> _applyEquippedTrail() async {
    if (!ref.read(backendEnabledProvider)) return;
    final cos = await ref.read(backendServiceProvider).myCosmetics();
    final info = cosmeticInfo(cos?.trail ?? 'trail_classic');
    if (info != null) {
      ref.read(mapServiceProvider).applyTrailColor(info.color.toARGB32());
    }
  }

  // Reverse-geocode a claimed ring's centre and toast the neighbourhood, so a
  // capture feels like conquering a real place. Fully best-effort.
  Future<void> _announceDistrict(List<List<double>> ring) async {
    if (ring.isEmpty) return;
    // Rough centroid: average the ring's points.
    var lng = 0.0, lat = 0.0;
    for (final p in ring) {
      lng += p[0];
      lat += p[1];
    }
    final district =
        await GeocodingService().districtFor(lng / ring.length, lat / ring.length);
    if (district == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🗺️ You claimed turf in $district!')),
    );
  }

  // Fire the big arcade capture celebration. ~1 coin per 100m² claimed.
  void _celebrate(double areaM2) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _celebration = CaptureCelebration(
        key: UniqueKey(),
        areaM2: areaM2,
        coins: (areaM2 / 100).floor(),
        areaLabel: settings.formatArea(areaM2),
        onDone: () {
          if (mounted) setState(() => _celebration = null);
        },
      );
    });
  }

  // Spawn (if needed) and draw power-up pickups around the player.
  Future<void> _loadPickups() async {
    if (!ref.read(backendEnabledProvider) || _lng == null) return;
    final backend = ref.read(backendServiceProvider);
    await backend.spawnPickupsNear(lng: _lng!, lat: _lat!);
    final pickups =
        await backend.pickupsNear(lng: _lng!, lat: _lat!, radiusMeters: 1000);
    if (!mounted) return;
    setState(() => _pickups = pickups);
    await ref.read(mapServiceProvider).drawPickups(pickups);
  }

  // Ask about streak reminders once, after the first claim of this session.
  bool _offeredReminders = false;
  void _offerRemindersOnce() {
    if (_offeredReminders) return;
    _offeredReminders = true;
    NotificationService().enableReminders();
  }

  // Grab any pickup within reach of the newest GPS point.
  Future<void> _tryCollect(List<double> point) async {
    if (_collecting || _pickups.isEmpty) return;
    final geometry = ref.read(geometryServiceProvider);
    Pickup? hit;
    for (final p in _pickups) {
      if (geometry.distanceMeters(point, [p.lng, p.lat]) <= 25) {
        hit = p;
        break;
      }
    }
    if (hit == null) return;

    _collecting = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final perk = await ref.read(backendServiceProvider).collectPickup(hit.id);
      if (ref.read(settingsProvider).haptics) HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(content: Text('🎁 Picked up ${perkName(perk)}!')),
      );
      await _loadPickups(); // refresh markers (and respawn if depleted)
    } catch (_) {
      // Already taken by someone else — just drop it from our local list.
      if (mounted) {
        setState(() => _pickups = _pickups.where((p) => p.id != hit!.id).toList());
      }
    } finally {
      _collecting = false;
    }
  }

  // Load and draw the saved best route (ghost run), if any.
  Future<void> _loadGhost() async {
    if (!ref.read(backendEnabledProvider)) return;
    final path = await ref.read(backendServiceProvider).ghostRunPath();
    if (path.length < 2) return;
    setState(() => _ghostPath = path);
    await ref.read(mapServiceProvider).drawGhostPath(path);
  }

  // Animate the 👻 marker stepping along the ghost path (loops).
  void _toggleGhost() {
    final map = ref.read(mapServiceProvider);
    if (_ghostPlaying) {
      _ghostTimer?.cancel();
      setState(() => _ghostPlaying = false);
      return;
    }
    if (_ghostPath.length < 2) return;
    setState(() => _ghostPlaying = true);
    var i = 0;
    _ghostTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (i >= _ghostPath.length) i = 0; // loop the replay
      map.moveGhostMarker(_ghostPath[i]);
      i++;
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    _ticker?.cancel();
    _ghostTimer?.cancel();
    _turfChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    if (!ref.read(backendEnabledProvider)) return;
    _turfChannel = ref.read(backendServiceProvider).subscribeTurf(() {
      if (mounted) _loadTurf();
    });
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runControllerProvider);
    final controller = ref.read(runControllerProvider.notifier);
    final mapService = ref.read(mapServiceProvider);

    // Whenever run state changes: redraw trail + claimed turf, follow the
    // newest point, and celebrate a fresh claim.
    ref.listen(runControllerProvider, (prev, next) {
      if (!_mapReady) return;

      mapService.drawTrail(next.trail);

      // Walked onto a power-up? Grab it.
      if (next.trail.length > (prev?.trail.length ?? 0) && next.trail.isNotEmpty) {
        _tryCollect(next.trail.last);
      }

      final messenger = ScaffoldMessenger.of(context);

      // Respect the player's sound/vibration preferences everywhere.
      final settings = ref.read(settingsProvider);

      // Safety prompt when a run begins (CLAUDE.md Part 5).
      final startedRun = next.isActive && !(prev?.isActive ?? false);
      if (startedRun) {
        _treasuresShown = 0;
        if (settings.haptics) HapticFeedback.selectionClick();
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text(
              '👀 Eyes up — pocket your phone, we keep tracking.',
            ),
            duration: Duration(seconds: 5),
          ));
      }

      // Distance treasures: celebrate each milestone crossed while walking.
      if (next.isActive) {
        final earned =
            (next.sessionDistanceM / AppConstants.treasureEveryMeters).floor();
        if (earned > _treasuresShown) {
          _treasuresShown = earned;
          final withPerk = _treasuresShown % AppConstants.treasurePerkEvery == 0;
          if (settings.haptics) HapticFeedback.mediumImpact();
          if (settings.sound) SystemSound.play(SystemSoundType.click);
          messenger
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: Text(withPerk
                  ? '🎁 Treasure! +${AppConstants.treasureCoins} coins & a perk!'
                  : '🎁 Treasure! +${AppConstants.treasureCoins} coins'),
              duration: const Duration(seconds: 2),
            ));
        }
      }

      // A new loop was closed this update -> redraw claims + toast the area.
      final gainedClaim = next.claims.length > (prev?.claims.length ?? 0);
      if (gainedClaim) {
        // Layered feedback: haptic thump + click, timed with the animation.
        if (settings.haptics) HapticFeedback.heavyImpact();
        if (settings.sound) SystemSound.play(SystemSoundType.click);
        _shake.forward(from: 0); // kick the screen-shake impact
        // Now that they've felt the payoff, it's a fair moment to ask about
        // streak reminders (asking at app launch tanks opt-in).
        _offerRemindersOnce();
        // Instant local fill in my color; realtime will reconcile the
        // authoritative server turf (including any steal) moments later.
        mapService.drawClaims(next.claims);
        _celebrate(next.lastClaimArea);
        _announceDistrict(next.claims.last); // "You claimed turf in Bandra!"
      }

      // Capture rejected for implausible speed.
      if (next.rejectedCount > (prev?.rejectedCount ?? 0)) {
        if (settings.haptics) HapticFeedback.vibrate();
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Too fast to count — capture rejected.'),
          ));
      }

      // Loop closed but the enclosed area was too small to bank. Tell the
      // player why in plain words so it never feels like a silent failure.
      if (next.smallLoopCount > (prev?.smallLoopCount ?? 0)) {
        if (settings.haptics) HapticFeedback.vibrate();
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Loop too small to claim — walk a bigger block '
                '(about 30 m across).'),
            duration: Duration(seconds: 4),
          ));
      }

      // Auto-paused at vehicle speed.
      if (next.autoPausedForSpeed && !(prev?.autoPausedForSpeed ?? false)) {
        if (settings.haptics) HapticFeedback.heavyImpact();
        messenger
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Run auto-paused: car-like speed detected. Stay safe!'),
            duration: Duration(seconds: 5),
          ));
      }

      if (next.trail.isNotEmpty) {
        final last = next.trail.last;
        mapService.centerOn(lng: last[0], lat: last[1]);
      }

      // Show/hide the dashed "close the loop" preview line back to the start.
      if (next.isActive &&
          next.previewGapMeters != null &&
          next.previewGapMeters! <= AppConstants.manualClaimMeters * 1.5 &&
          next.trail.length >= 4) {
        mapService.drawPreviewLine(next.trail.last, next.trail.first);
      } else if (!next.isActive || next.trail.length < 4) {
        mapService.drawPreviewLine(null, null);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Run')),
      body: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          // Decaying horizontal jitter: strong at the start, gone by the end.
          final t = _shake.value;
          final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 7) * (1 - t) * 9;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Stack(
        children: [
          MapWidget(
            key: const ValueKey('runMap'),
            styleUri: MapboxStyles.DARK, // match the app's dark brand
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _StatsPanel(run: run, settings: ref.watch(settingsProvider)),
                if (run.isActive) ...[
                  const SizedBox(height: 10),
                  _LoopHud(
                    points: run.trail.length,
                    metersToClose: run.previewGapMeters,
                    previewAreaM: run.previewAreaM,
                    pickupsNearby: _pickups.length,
                    gpsAccuracy: run.gpsAccuracy,
                  ),
                ],
              ],
            ),
          ),
          if (_ghostPath.length >= 2)
            Positioned(
              top: 8,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'ghost',
                onPressed: _toggleGhost,
                child: Text(_ghostPlaying ? '⏸' : '👻',
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
          // Manual claim rescue — appears when you're close enough to close.
          if (run.canClaimNow)
            Positioned(
              left: 24,
              right: 24,
              bottom: 96,
              child: _ClaimNowButton(
                areaM: run.previewAreaM,
                onClaim: () {
                  if (ref.read(settingsProvider).haptics) {
                    HapticFeedback.mediumImpact();
                  }
                  controller.claimNow();
                },
              ),
            ),
          // The capture payoff — drawn above everything while it plays.
          if (_celebration != null) Positioned.fill(child: _celebration!),
        ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: run.isActive
                ? () {
                    controller.stop();
                    final ended = ref.read(runControllerProvider);
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => RunSummaryScreen(
                        areaM: ended.sessionAreaM,
                        distanceM: ended.sessionDistanceM,
                        duration: ended.duration,
                      ),
                    ));
                  }
                : controller.start,
            child: Text(run.isActive ? 'Stop Run' : 'Start Run'),
          ),
        ),
      ),
    );
  }
}

// Live run stats: time, distance, and area claimed this session.
class _StatsPanel extends StatelessWidget {
  final RunState run;
  final AppSettings settings;
  const _StatsPanel({required this.run, required this.settings});

  String get _time {
    final d = run.duration;
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _distance => settings.formatDistance(run.sessionDistanceM);

  @override
  Widget build(BuildContext context) {
    if (!run.isActive && run.claims.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Ready',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Time', value: _time),
          _Stat(label: 'Distance', value: _distance),
          _Stat(
              label: 'Claimed',
              value: settings.formatArea(run.sessionAreaM)),
        ],
      ),
    );
  }
}

// The manual-claim rescue button — a pulsing green CTA that appears when you're
// close enough to force the loop closed.
class _ClaimNowButton extends StatefulWidget {
  final double areaM;
  final VoidCallback onClaim;
  const _ClaimNowButton({required this.areaM, required this.onClaim});

  @override
  State<_ClaimNowButton> createState() => _ClaimNowButtonState();
}

class _ClaimNowButtonState extends State<_ClaimNowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpace.radiusSm),
          boxShadow: [
            BoxShadow(
                color: AppColors.go.withValues(alpha: 0.35 + 0.35 * _c.value),
                blurRadius: 22 + 12 * _c.value,
                spreadRadius: 1),
          ],
        ),
        child: child,
      ),
      child: GameButton(
        label: 'CLAIM ${widget.areaM.toStringAsFixed(0)} m²',
        icon: Icons.flag_circle,
        gradient: AppColors.goGradient,
        onPressed: widget.onClaim,
      ),
    );
  }
}

class _LoopHud extends StatelessWidget {
  final int points;
  final double? metersToClose;
  final double previewAreaM;
  final int pickupsNearby;
  final double? gpsAccuracy;
  const _LoopHud({
    required this.points,
    required this.metersToClose,
    required this.previewAreaM,
    required this.pickupsNearby,
    required this.gpsAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    final m = metersToClose;
    final acc = gpsAccuracy;
    final weakSignal = acc != null && acc > AppConstants.maxGpsAccuracyMeters;
    final closing = m != null && m <= AppConstants.manualClaimMeters;
    var color = closing ? AppColors.ownershipPalette[2] : AppColors.accent;

    String headline;
    String sub;
    // Weak GPS beats every other message: nothing can be tracked, and the
    // player deserves to know why rather than watching a frozen 0m.
    if (weakSignal) {
      color = AppColors.ownershipPalette[5]; // warning tone
      headline = 'Weak GPS signal (±${acc.toStringAsFixed(0)} m)';
      sub = 'Head outside with a clear view of the sky — indoors is too '
          'inaccurate to track a run.';
    } else if (points < 3 || m == null) {
      headline = 'Draw your trail';
      sub = 'Walk a loop, then return to your start to claim the middle.';
    } else if (closing && previewAreaM >= AppConstants.minClaimAreaM2) {
      // Live preview: show the area you'd bank and the coins for it.
      headline = 'Close now: ${previewAreaM.toStringAsFixed(0)} m²';
      sub = '+${(previewAreaM / 100).floor()} coins — tap CLAIM or reach '
          'your start (${m.toStringAsFixed(0)} m).';
    } else {
      headline = '${m.toStringAsFixed(0)} m to close your loop';
      sub = 'Return near your starting point to claim.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  weakSignal
                      ? Icons.signal_cellular_connected_no_internet_0_bar
                      : (closing ? Icons.flag_circle : Icons.my_location),
                  color: color,
                  size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(headline,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              if (pickupsNearby > 0)
                Text('🎁 $pickupsNearby',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
