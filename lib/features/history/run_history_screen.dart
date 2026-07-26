// run_history_screen.dart — Every run you've completed, newest first, with a
// lifetime summary at the top. Distances respect the unit setting.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../models/run.dart';
import '../../services/settings_service.dart';

final runHistoryProvider = FutureProvider.autoDispose<List<Run>>((ref) async {
  if (!ref.read(backendEnabledProvider)) return const [];
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.myRuns(limit: 100);
});

class RunHistoryScreen extends ConsumerWidget {
  const RunHistoryScreen({super.key});

  static String _when(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  static String _duration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(runHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Run history')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history: $e')),
        data: (runs) {
          if (runs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No runs yet.\nStart a run and claim your first turf!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final totalArea =
              runs.fold<double>(0, (sum, r) => sum + r.areaGained);
          final totalDist =
              runs.fold<double>(0, (sum, r) => sum + r.distance);

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(runHistoryProvider.future),
            child: ListView.separated(
              itemCount: runs.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  // Lifetime summary header.
                  return Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: GamePanel(
                      borderColor: AppColors.accent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Summary(label: 'Runs', value: '${runs.length}'),
                          _Summary(
                              label: 'Territory made',
                              value: settings.formatArea(totalArea)),
                          _Summary(
                              label: 'Walked',
                              value: settings.formatDistance(totalDist)),
                        ],
                      ),
                    ),
                  );
                }

                final r = runs[i - 1];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.flag, color: Colors.black),
                  ),
                  title: Text(settings.formatArea(r.areaGained),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${settings.formatDistance(r.distance)} · ${_duration(r.duration)}'),
                  trailing: Text(_when(r.startedAt),
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  const _Summary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
