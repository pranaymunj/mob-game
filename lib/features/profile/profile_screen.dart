// profile_screen.dart — The player's account, streak, Home Base, and privacy
// controls. Home base is stored block-level approximate (never an address).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../models/player.dart';
import '../../models/player_stats.dart';
import '../friends/friends_screen.dart';
import '../history/run_history_screen.dart';
import '../perks/perk_info.dart';
import '../progression/achievements.dart';
import 'account_section.dart';
import 'edit_profile_screen.dart';

// Loads the current player's profile (streak, home base, area). Autodisposes so
// it refetches each visit.
final myPlayerProvider = FutureProvider.autoDispose<Player?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.myPlayer();
});

final perksProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  if (!ref.read(backendEnabledProvider)) return {};
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.perks();
});

final myCrewProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.myCrewName();
});

final statsProvider = FutureProvider.autoDispose<PlayerStats?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.playerStats();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _setHomeBase(BuildContext context, WidgetRef ref) async {
    final here = await ref.read(locationServiceProvider).current();
    if (here == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location unavailable. Enable it in Settings.')),
        );
      }
      return;
    }
    await ref.read(backendServiceProvider).setHomeBase(lng: here.lng, lat: here.lat);
    ref.invalidate(myPlayerProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home base set (approximate, block-level).')),
      );
    }
  }

  Future<void> _activatePerk(BuildContext context, WidgetRef ref, String key) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backendServiceProvider).activatePerk(key);
      ref.invalidate(perksProvider);
      final msg = key == 'shield'
          ? 'Shield active — your turf is protected for 24h.'
          : '${perkName(key)} activated.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not activate: $e')));
    }
  }

  Future<void> _crewAction(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(myCrewProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Crew updated.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<String?> _promptName(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Crew name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all my data?'),
        content: const Text(
          'This permanently erases your account, all your turf, and your run '
          'history. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(backendServiceProvider).deleteMyData();
    ref.invalidate(myPlayerProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your data has been deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendOn = ref.watch(backendEnabledProvider);
    final playerAsync = ref.watch(myPlayerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: playerAsync.value != null
                      ? Color(playerAsync.value!.colorValue)
                      : Colors.grey,
                  child: playerAsync.value?.avatar == null
                      ? const Icon(Icons.person, size: 44, color: Colors.black)
                      : Text(playerAsync.value!.avatar!,
                          style: const TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 10),
                Text(
                  playerAsync.value?.displayName ?? 'Player',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: playerAsync.value == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EditProfileScreen(
                                  player: playerAsync.value!),
                            ),
                          ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Level + XP + lifetime "territory made".
          ref.watch(statsProvider).maybeWhen(
                data: (s) => s == null ? const SizedBox.shrink() : _LevelBanner(s),
                orElse: () => const SizedBox.shrink(),
              ),
          const SizedBox(height: 20),

          // Streak + area stats.
          playerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load profile: $e'),
            data: (p) {
              if (p == null) {
                return const Text('Sign-in/backend not configured.');
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department,
                          label: 'Day streak',
                          value: '${p.currentStreak}',
                          sub: 'best ${p.longestStreak}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.crop_square,
                          label: 'Total turf',
                          value: '${p.totalArea.toStringAsFixed(0)} m²',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.home),
                      title: const Text('Home base'),
                      subtitle: Text(p.hasHomeBase
                          ? 'Set (approximate, block-level)'
                          : 'Not set'),
                      trailing: TextButton(
                        onPressed: () => _setHomeBase(context, ref),
                        child: Text(p.hasHomeBase ? 'Update' : 'Set here'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Perks inventory (earned from the daily challenge).
          const SectionLabel('Perks', icon: Icons.bolt),
          const SizedBox(height: 8),
          ref.watch(perksProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load perks: $e'),
                data: (perks) {
                  final owned = perks.entries.where((e) => e.value > 0).toList();
                  if (owned.isEmpty) {
                    return const Text(
                      'No perks yet. Complete the daily challenge to earn one!',
                      style: TextStyle(color: Colors.grey),
                    );
                  }
                  return Column(
                    children: [
                      for (final e in owned)
                        Card(
                          child: ListTile(
                            leading: Icon(perkIcon(e.key)),
                            title: Text('${perkName(e.key)}  ×${e.value}'),
                            subtitle: Text(perkInfos[e.key]?.blurb ?? ''),
                            trailing: TextButton(
                              onPressed: () => _activatePerk(context, ref, e.key),
                              child: const Text('Use'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          const SizedBox(height: 24),

          // Achievements.
          const SectionLabel('Achievements', icon: Icons.emoji_events),
          const SizedBox(height: 8),
          ref.watch(statsProvider).maybeWhen(
                data: (s) => s == null
                    ? const SizedBox.shrink()
                    : _AchievementsGrid(stats: s),
                orElse: () => const SizedBox.shrink(),
              ),
          const SizedBox(height: 24),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Friends'),
                  subtitle: const Text('Invite friends, earn coins together'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const FriendsScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Run history'),
                  subtitle: const Text('Every run and turf you\'ve claimed'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const RunHistoryScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account (guest vs. secured).
          const AccountSection(),
          const SizedBox(height: 24),

          // Crew.
          const SectionLabel('Crew', icon: Icons.groups),
          const SizedBox(height: 8),
          ref.watch(myCrewProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load crew: $e'),
                data: (crew) {
                  if (crew != null) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.groups),
                        title: Text(crew),
                        subtitle: const Text('Your crew pools its turf on the leaderboard.'),
                        trailing: TextButton(
                          onPressed: () => _crewAction(context, ref,
                              () => ref.read(backendServiceProvider).leaveCrew()),
                          child: const Text('Leave'),
                        ),
                      ),
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create'),
                          onPressed: () async {
                            final name = await _promptName(context, 'Create a crew');
                            if (name != null && name.isNotEmpty && context.mounted) {
                              await _crewAction(context, ref,
                                  () => ref.read(backendServiceProvider).createCrew(name));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Join'),
                          onPressed: () async {
                            final name = await _promptName(context, 'Join a crew');
                            if (name != null && name.isNotEmpty && context.mounted) {
                              await _crewAction(context, ref,
                                  () => ref.read(backendServiceProvider).joinCrew(name));
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(children: [
                    Icon(Icons.privacy_tip_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Your privacy', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  SizedBox(height: 8),
                  Text(
                    'Claimr shows turf, never people. Others see the land you '
                    'claim — never your live location. Home base is stored only '
                    'at approximate, block-level precision.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: backendOn ? () => _deleteData(context, ref) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete my data'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: AppColors.muted)),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// Level + XP progress + lifetime "territory made".
class _LevelBanner extends StatelessWidget {
  final PlayerStats s;
  const _LevelBanner(this.s);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Text("${s.level}",
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Level ${s.level}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Territory made: ${s.lifetimeArea.toStringAsFixed(0)} m²",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s.levelProgress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 4),
          Text("${s.xpIntoLevel} / ${s.xpForLevel} XP to level ${s.level + 1}",
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

// Grid of badges; unlocked ones are colored, locked are dimmed.
class _AchievementsGrid extends StatelessWidget {
  final PlayerStats stats;
  const _AchievementsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in allAchievements)
          _Badge(a: a, unlocked: a.unlocked(stats)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final Achievement a;
  final bool unlocked;
  const _Badge({required this.a, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? AppColors.ownershipPalette[0] : Colors.white24;
    return Tooltip(
      message: "${a.name} — ${a.description}",
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: unlocked ? 1 : 0.15),
              child: Icon(a.icon,
                  color: unlocked ? Colors.black : Colors.white38),
            ),
            const SizedBox(height: 4),
            Text(a.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 10,
                    color: unlocked ? Colors.white : Colors.white38)),
          ],
        ),
      ),
    );
  }
}
