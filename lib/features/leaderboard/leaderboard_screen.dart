// leaderboard_screen.dart — Two tabs: players by area, and crews by pooled area.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../models/crew.dart';
import '../../models/player.dart';

// A rank badge: the number in the entity's colour, ringed gold/silver/bronze
// for the top three — the competitive-leaderboard convention.
Widget _rankBadge(int rank, Color inner) {
  const medals = {1: Color(0xFFF0B429), 2: Color(0xFFC0C7D0), 3: Color(0xFFCD7F32)};
  final ring = medals[rank];
  return Container(
    padding: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: ring ?? Colors.transparent,
      boxShadow: ring != null
          ? [BoxShadow(color: ring.withValues(alpha: 0.6), blurRadius: 10)]
          : null,
    ),
    child: CircleAvatar(
      radius: 18,
      backgroundColor: inner,
      child: Text('$rank',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w900)),
    ),
  );
}

final leaderboardProvider = FutureProvider.autoDispose<List<Player>>((ref) async {
  if (!ref.read(backendEnabledProvider)) return const [];
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.leaderboard(limit: 20);
});

final crewLeaderboardProvider = FutureProvider.autoDispose<List<Crew>>((ref) async {
  if (!ref.read(backendEnabledProvider)) return const [];
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.crewLeaderboard(limit: 20);
});

final seasonLeaderboardProvider =
    FutureProvider.autoDispose<List<Player>>((ref) async {
  if (!ref.read(backendEnabledProvider)) return const [];
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.seasonLeaderboard(limit: 20);
});

final seasonNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.currentSeasonName();
});

final leagueStatusProvider = FutureProvider.autoDispose<
    ({int tier, String label, double weekly, int rank, int size})?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.leagueStatus();
});

final leagueStandingsProvider =
    FutureProvider.autoDispose<List<Player>>((ref) async {
  if (!ref.read(backendEnabledProvider)) return const [];
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.leagueStandings(limit: 25);
});

// Tier colour + emoji for the league badge.
({Color color, String emoji}) tierStyle(int tier) => switch (tier) {
      4 => (color: const Color(0xFF8AB4F8), emoji: '💎'),
      3 => (color: const Color(0xFFCBD5E1), emoji: '🔷'),
      2 => (color: AppColors.gold, emoji: '🥇'),
      1 => (color: const Color(0xFFB0BEC5), emoji: '🥈'),
      _ => (color: const Color(0xFFCD7F32), emoji: '🥉'),
    };

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  static int _hexToArgb(String hex) =>
      int.parse('FF${hex.replaceFirst('#', '')}', radix: 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'League'),
              Tab(text: 'Players'),
              Tab(text: 'Crews'),
              Tab(text: 'Season'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LeagueTab(),
            _PlayersTab(),
            _CrewsTab(),
            _SeasonTab(),
          ],
        ),
      ),
    );
  }
}

class _LeagueTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(leagueStatusProvider).value;
    final async = ref.watch(leagueStandingsProvider);
    final style = tierStyle(status?.tier ?? 0);

    return Column(
      children: [
        // Your division badge + weekly rank.
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: GamePanel(
            borderColor: style.color,
            child: Row(
              children: [
                Text(style.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: AppSpace.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${status?.label ?? 'Bronze'} League',
                        style: TextStyle(
                            color: style.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    Text(
                      status == null
                          ? 'Claim turf to enter the rankings'
                          : 'Rank #${status.rank} of ${status.size} this week',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                if (status != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${status.weekly.toStringAsFixed(0)} m²',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                      const Text('this week',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load: $e')),
            data: (players) {
              if (players.isEmpty) {
                return const Center(
                    child: Text('No one has claimed turf this week yet.'));
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(leagueStandingsProvider.future),
                child: ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = players[i];
                    return ListTile(
                      leading: _rankBadge(i + 1, Color(p.colorValue)),
                      title: Text(p.avatar == null
                          ? p.displayName
                          : '${p.avatar}  ${p.displayName}'),
                      trailing: Text('${p.totalArea.toStringAsFixed(0)} m²',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlayersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (players) {
        if (players.isEmpty) {
          return const Center(child: Text('No turf claimed yet. Go start a run!'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(leaderboardProvider.future),
          child: ListView.separated(
            itemCount: players.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = players[i];
              return ListTile(
                leading: _rankBadge(i + 1, Color(p.colorValue)),
                title: Text(p.displayName),
                trailing: Text('${p.totalArea.toStringAsFixed(0)} m²',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            },
          ),
        );
      },
    );
  }
}

class _SeasonTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(seasonNameProvider);
    final async = ref.watch(seasonLeaderboardProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: GamePanel(
            borderColor: AppColors.gold,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  name.value ?? 'Current season',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load: $e')),
            data: (players) {
              if (players.isEmpty) {
                return const Center(child: Text('No turf claimed this season yet.'));
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(seasonLeaderboardProvider.future),
                child: ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = players[i];
                    return ListTile(
                      leading: _rankBadge(i + 1, Color(p.colorValue)),
                      title: Text(p.displayName),
                      trailing: Text('${p.totalArea.toStringAsFixed(0)} m²',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CrewsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crewLeaderboardProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (crews) {
        if (crews.isEmpty) {
          return const Center(
              child: Text('No crews yet. Create one from your Profile!'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(crewLeaderboardProvider.future),
          child: ListView.separated(
            itemCount: crews.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = crews[i];
              return ListTile(
                leading:
                    _rankBadge(i + 1, Color(LeaderboardScreen._hexToArgb(c.colorHex))),
                title: Text(c.name),
                subtitle: Text('${c.members} member${c.members == 1 ? '' : 's'}'),
                trailing: Text('${c.totalArea.toStringAsFixed(0)} m²',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            },
          ),
        );
      },
    );
  }
}
