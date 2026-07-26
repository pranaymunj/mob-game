// friends_screen.dart — Your share code (invite a friend, both earn coins),
// a box to redeem/add a friend's code, and a board of your friends ranked by
// this week's area.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../models/player.dart';
import '../profile/profile_screen.dart';

final referralCodeProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.myReferralCode();
});

final friendsBoardProvider = FutureProvider.autoDispose<List<Player>>((ref) async {
  if (!ref.read(backendEnabledProvider)) return const [];
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.friendsBoard();
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _codeInput = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeInput.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeInput.text.trim();
    if (code.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final balance = await ref.read(backendServiceProvider).redeemReferral(code);
      ref.invalidate(friendsBoardProvider);
      ref.invalidate(myPlayerProvider);
      _codeInput.clear();
      messenger.showSnackBar(SnackBar(
          content: Text('Code redeemed! +50 coins — balance $balance')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFriend() async {
    final code = _codeInput.text.trim();
    if (code.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).addFriend(code);
      ref.invalidate(friendsBoardProvider);
      _codeInput.clear();
      messenger.showSnackBar(const SnackBar(content: Text('Friend added!')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = ref.watch(referralCodeProvider).value;
    final board = ref.watch(friendsBoardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          // Your invite code.
          const SectionLabel('Invite a friend', icon: Icons.card_giftcard),
          GamePanel(
            borderColor: AppColors.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share your code. When a friend redeems it, you get 100 coins '
                  'and they get 50.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppSpace.radiusSm),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          code ?? '••••••',
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: AppColors.gold),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    IconButton.filledTonal(
                      onPressed: code == null
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')),
                              );
                            },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                GameButton(
                  label: 'SHARE INVITE',
                  icon: Icons.share,
                  gradient: AppColors.goldGradient,
                  dense: true,
                  onPressed: code == null
                      ? null
                      : () => SharePlus.instance.share(ShareParams(
                          text: 'Join me on Claimr! Use my code $code and we '
                              'both get coins. 🚩')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),

          // Redeem / add a code.
          const SectionLabel('Enter a code', icon: Icons.person_add),
          GamePanel(
            child: Column(
              children: [
                TextField(
                  controller: _codeInput,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Friend\'s code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: GameButton(
                        label: 'REDEEM +50',
                        gradient: AppColors.goldGradient,
                        dense: true,
                        onPressed: _busy ? null : _redeem,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: GameButton(
                        label: 'ADD FRIEND',
                        gradient: AppColors.accentGradient,
                        dense: true,
                        onPressed: _busy ? null : _addFriend,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                const Text(
                  'Redeem once for the coin bonus. Add friends anytime.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),

          // Friends board.
          const SectionLabel('Your friends this week', icon: Icons.people),
          board.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load friends: $e',
                style: const TextStyle(color: AppColors.muted)),
            data: (friends) {
              if (friends.isEmpty) {
                return const Text(
                  'No friends yet. Share your code to add some!',
                  style: TextStyle(color: AppColors.muted),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < friends.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(friends[i].colorValue),
                        child: Text(friends[i].avatar ?? '${i + 1}',
                            style: const TextStyle(color: Colors.black)),
                      ),
                      title: Text(friends[i].displayName),
                      trailing: Text(
                          '${friends[i].totalArea.toStringAsFixed(0)} m²',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
