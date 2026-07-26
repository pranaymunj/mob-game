// daily_reward.dart — The 7-day login ladder shown on the main menu.
// Only appears when there's something to claim, so the menu stays clean.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../perks/perk_info.dart';
import '../profile/profile_screen.dart';

final dailyLoginProvider =
    FutureProvider.autoDispose<({int day, bool claimable, int nextCoins})?>(
        (ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.dailyLoginStatus();
});

// Coins per day — mirrors login_reward_coins() in 0018_daily_login.sql.
const _ladder = [10, 15, 25, 40, 60, 80, 150];

class DailyRewardCard extends ConsumerStatefulWidget {
  const DailyRewardCard({super.key});

  @override
  ConsumerState<DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends ConsumerState<DailyRewardCard> {
  bool _busy = false;

  Future<void> _claim() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await ref.read(backendServiceProvider).claimLoginReward();
      ref.invalidate(dailyLoginProvider);
      ref.invalidate(myPlayerProvider);
      ref.invalidate(perksProvider);
      final perkPart = r.perk == null ? '' : ' + ${perkName(r.perk!)}!';
      messenger.showSnackBar(SnackBar(
        content: Text('Day ${r.day} reward: 🪙 ${r.coins}$perkPart'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dailyLoginProvider).value;
    // Nothing to claim (or backend off) -> take up no space at all.
    if (status == null || !status.claimable) return const SizedBox.shrink();

    final gold = AppColors.ownershipPalette[3];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🎁', style: TextStyle(fontSize: 16, color: gold)),
              const SizedBox(width: 8),
              Text('DAILY REWARD',
                  style: TextStyle(
                      color: gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
              const Spacer(),
              Text('Day ${status.day} of 7',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          // The ladder, so you can see the day-7 prize coming.
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: d == status.day
                          ? gold.withValues(alpha: 0.25)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: d == status.day ? gold : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('$d',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 9)),
                        Text('${_ladder[d - 1]}',
                            style: TextStyle(
                              color: d == status.day ? gold : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            )),
                        if (d == 7)
                          const Text('+perk',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 7)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GameButton(
            label: _busy ? 'CLAIMING…' : 'CLAIM  ${status.nextCoins}',
            icon: Icons.monetization_on,
            gradient: AppColors.goldGradient,
            dense: true,
            onPressed: _busy ? null : _claim,
          ),
        ],
      ),
    );
  }
}
