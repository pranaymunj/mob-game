// run_summary_screen.dart — Shown after a run ends: area gained, distance, time,
// with a Share button that exports the summary card as an image (Strava-style).

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import 'run_controller.dart';

class RunSummaryScreen extends StatefulWidget {
  final double areaM;
  final double distanceM;
  final Duration duration;
  const RunSummaryScreen({
    super.key,
    required this.areaM,
    required this.distanceM,
    required this.duration,
  });

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen> {
  final _cardKey = GlobalKey();

  String get _time {
    final m = widget.duration.inMinutes;
    final s = widget.duration.inSeconds % 60;
    return '${m}m ${s}s';
  }

  String get _distance => widget.distanceM >= 1000
      ? '${(widget.distanceM / 1000).toStringAsFixed(2)} km'
      : '${widget.distanceM.toStringAsFixed(0)} m';

  Future<void> _share() async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final file = XFile.fromData(
        bytes.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'claimr_run.png',
      );
      await SharePlus.instance.share(ShareParams(
        files: [file],
        text: 'I claimed ${widget.areaM.toStringAsFixed(0)} m² of turf on Claimr! 🚩',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share right now.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run complete')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // The shareable card.
            RepaintBoundary(
              key: _cardKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Text('🚩', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text('Claimr',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _StatTile(
                        icon: Icons.crop_square,
                        label: 'Turf claimed',
                        value: '${widget.areaM.toStringAsFixed(0)} m²',
                        color: AppColors.ownershipPalette[2]),
                    const SizedBox(height: 12),
                    _StatTile(
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: _distance,
                        color: AppColors.ownershipPalette[1]),
                    const SizedBox(height: 12),
                    _StatTile(
                        icon: Icons.timer_outlined,
                        label: 'Time',
                        value: _time,
                        color: AppColors.ownershipPalette[0]),
                  ],
                ),
              ),
            ),
            // Deliberately OUTSIDE the RepaintBoundary above: this is a
            // diagnostic, not a brag, and nobody shares "used 6% battery".
            //
            // The reading lands asynchronously after the run stops, so this
            // watches the controller rather than taking a snapshot with the
            // rest of the stats — otherwise it would always render null.
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final usage =
                    ref.watch(runControllerProvider.select((s) => s.battery));
                if (usage == null) return const SizedBox.shrink();

                final String text;
                if (usage.chargedDuringRun) {
                  text = 'Battery — not measured (charging)';
                } else if (!usage.isMeaningful) {
                  text = 'Battery — run too short to measure';
                } else {
                  final perHour = usage.percentPerHour!.toStringAsFixed(1);
                  final perKm = usage.percentPerKm;
                  text = 'Battery — ${usage.drainPercent}% used  ·  '
                      '$perHour%/hr'
                      '${perKm == null ? '' : '  ·  ${perKm.toStringAsFixed(1)}%/km'}';
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.battery_5_bar_outlined,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.black)),
        const SizedBox(width: 16),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
