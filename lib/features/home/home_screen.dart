// home_screen.dart — The main menu. Built to feel like a game: living territory
// art, a player HUD (level / XP / streak), the daily challenge framed as a
// mission, and one dominant Start Run call-to-action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../models/challenge.dart';
import '../../models/player_stats.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';
import '../map_world/world_screen.dart';
import '../perks/perk_info.dart';
import '../profile/profile_screen.dart';
import '../run/run_screen.dart';
import 'daily_reward.dart';
import 'territory_backdrop.dart';

final challengeProvider = FutureProvider.autoDispose<Challenge?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.challengeStatus();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _claimReward(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final perk = await ref.read(backendServiceProvider).claimDailyReward();
      ref.invalidate(challengeProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('🎁 Reward earned: ${perkName(perk)}!')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Reward already claimed today.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(challengeProvider);
    final stats = ref.watch(statsProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const TerritoryBackdrop(),
          // Darken toward the bottom so the CTA stays legible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC0B0E14)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlayerHud(
                    stats: stats.value,
                    coins: ref.watch(myPlayerProvider).value?.coins ?? 0,
                  ),
                  const Spacer(),
                  // Wordmark
                  Text(
                    AppConstants.appName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: AppColors.accent.withValues(alpha: 0.6),
                                blurRadius: 24),
                          ],
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text('Walk. Claim. Defend.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 2)),
                  const Spacer(),
                  const DailyRewardCard(),
                  challenge.maybeWhen(
                    data: (c) => c == null
                        ? const SizedBox.shrink()
                        : _MissionCard(c,
                            onClaimReward: () => _claimReward(context, ref)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),
                  const _StartRunButton(),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _MenuIcon(
                          icon: Icons.map, label: 'Map', screen: WorldScreen()),
                      _MenuIcon(
                          icon: Icons.storefront,
                          label: 'Shop',
                          screen: ShopScreen()),
                      _MenuIcon(
                          icon: Icons.leaderboard,
                          label: 'Ranks',
                          screen: LeaderboardScreen()),
                      _MenuIcon(
                          icon: Icons.person,
                          label: 'Profile',
                          screen: ProfileScreen()),
                      _MenuIcon(
                          icon: Icons.settings,
                          label: 'Settings',
                          screen: SettingsScreen()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Level badge + XP bar + streak flame — the "you have a character" header.
class _PlayerHud extends StatelessWidget {
  final PlayerStats? stats;
  final int coins;
  const _PlayerHud({this.stats, this.coins = 0});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
              boxShadow: [
                BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 14),
              ],
            ),
            child: Text('${s?.level ?? 1}',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(s?.lifetimeArea ?? 0).toStringAsFixed(0)} m² claimed',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s?.levelProgress ?? 0,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HudStat(
            icon: Icons.monetization_on,
            color: AppColors.gold,
            value: '$coins',
          ),
          const SizedBox(width: 14),
          _HudStat(
            icon: Icons.local_fire_department,
            color: const Color(0xFFFF7043),
            value: '${s?.currentStreak ?? 0}',
          ),
        ],
      ),
    );
  }
}

// A compact icon + value pair for the top HUD (coins, streak).
class _HudStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  const _HudStat(
      {required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

// The daily challenge, framed as a mission briefing.
class _MissionCard extends StatelessWidget {
  final Challenge c;
  final VoidCallback onClaimReward;
  const _MissionCard(this.c, {required this.onClaimReward});

  @override
  Widget build(BuildContext context) {
    final accent = c.completed ? AppColors.ownershipPalette[2] : AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.completed ? Icons.emoji_events : Icons.flag,
                  color: accent, size: 18),
              const SizedBox(width: 8),
              Text('TODAY\'S MISSION',
                  style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
              const Spacer(),
              Text(c.progressLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: c.fraction,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          if (c.completed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onClaimReward,
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Claim reward'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// The one thing we want you to press.
class _StartRunButton extends StatefulWidget {
  const _StartRunButton();

  @override
  State<_StartRunButton> createState() => _StartRunButtonState();
}

class _StartRunButtonState extends State<_StartRunButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A pulsing green glow behind the big 3D go-button draws the eye.
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpace.radiusSm),
          boxShadow: [
            BoxShadow(
              color: AppColors.go.withValues(alpha: 0.35 + 0.30 * _c.value),
              blurRadius: 26 + 14 * _c.value,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
      child: GameButton(
        label: 'START RUN',
        icon: Icons.play_arrow_rounded,
        gradient: AppColors.goGradient,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RunScreen()),
        ),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget screen;
  const _MenuIcon(
      {required this.icon, required this.label, required this.screen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => screen),
      ),
      child: Padding(
        // Kept tight: five destinations must fit across a narrow phone.
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
