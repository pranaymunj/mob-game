// shop_screen.dart — Spend coins on perks.
//
// Prices are duplicated here for display only; the server is the authority and
// re-checks both the price and your balance on every purchase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../perks/perk_info.dart';
import '../profile/profile_screen.dart';
import 'cosmetics_catalog.dart';

// Display prices — must match buy_perk() in 0017_currency.sql.
const perkPrices = <String, int>{
  'sprint': 50,
  'recon': 75,
  'wide_brush': 100,
  'shield': 150,
};

// Owned cosmetics + equipped slots.
final cosmeticsProvider = FutureProvider.autoDispose<
    ({List<String> owned, String trail, String turf})?>((ref) async {
  if (!ref.read(backendEnabledProvider)) return null;
  final backend = ref.read(backendServiceProvider);
  await backend.signIn();
  return backend.myCosmetics();
});

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String? _buying;

  Future<void> _buy(String perk) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _buying = perk);
    try {
      final remaining = await ref.read(backendServiceProvider).buyPerk(perk);
      ref.invalidate(myPlayerProvider);
      ref.invalidate(perksProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('Bought ${perkName(perk)} — $remaining coins left'),
      ));
    } catch (e) {
      // Surface the server's message (e.g. "not enough coins: need 150...").
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  Future<void> _buyCosmetic(CosmeticInfo c) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _buying = c.key);
    try {
      final left = await ref.read(backendServiceProvider).buyCosmetic(c.key);
      ref.invalidate(myPlayerProvider);
      ref.invalidate(cosmeticsProvider);
      messenger.showSnackBar(
          SnackBar(content: Text('Bought ${c.name} — $left coins left')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  Future<void> _equipCosmetic(CosmeticInfo c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backendServiceProvider).equipCosmetic(c.key);
      ref.invalidate(cosmeticsProvider);
      messenger.showSnackBar(SnackBar(content: Text('${c.name} equipped')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(myPlayerProvider).value?.coins ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shop'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Perks'),
            Tab(text: 'Trails'),
            Tab(text: 'Turf'),
          ]),
        ),
        body: Column(
          children: [
            _BalanceBanner(coins: coins),
            Expanded(
              child: TabBarView(
                children: [
                  _perksTab(coins),
                  _cosmeticsTab(coins, trailCatalog),
                  _cosmeticsTab(coins, turfCatalog),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perksTab(int coins) {
    final owned = ref.watch(perksProvider).value ?? const <String, int>{};
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final entry in perkPrices.entries)
          _ShopTile(
            perk: entry.key,
            price: entry.value,
            ownedQty: owned[entry.key] ?? 0,
            canAfford: coins >= entry.value,
            busy: _buying == entry.key,
            onBuy: () => _buy(entry.key),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _cosmeticsTab(int coins, List<CosmeticInfo> catalog) {
    final cos = ref.watch(cosmeticsProvider).value;
    final owned = cos?.owned ?? const <String>[];
    final equippedTrail = cos?.trail ?? 'trail_classic';
    final equippedTurf = cos?.turf ?? 'turf_solid';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final c in catalog)
          _CosmeticTile(
            info: c,
            owned: c.price == 0 || owned.contains(c.key),
            equipped: c.key == equippedTrail || c.key == equippedTurf,
            canAfford: coins >= c.price,
            busy: _buying == c.key,
            onBuy: () => _buyCosmetic(c),
            onEquip: () => _equipCosmetic(c),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BalanceBanner extends StatelessWidget {
  final int coins;
  const _BalanceBanner({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
      child: GamePanel(
        borderColor: AppColors.gold,
        child: Row(
          children: [
            // Gold coin chip for a bit of shine.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
              ),
              child: const Text('🪙', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: AppSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$coins',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold)),
                const Text('coins',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Flexible(
              child: Text('Earn coins by walking\n& claiming turf',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// A trail skin or turf style: buy it, then equip it.
class _CosmeticTile extends StatelessWidget {
  final CosmeticInfo info;
  final bool owned;
  final bool equipped;
  final bool canAfford;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _CosmeticTile({
    required this.info,
    required this.owned,
    required this.equipped,
    required this.canAfford,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: GamePanel(
        borderColor: equipped ? info.color : null,
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            // Glowing colour swatch previewing the skin.
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: info.color,
                borderRadius: BorderRadius.circular(AppSpace.radiusSm),
                boxShadow: [
                  BoxShadow(
                      color: info.color.withValues(alpha: 0.7), blurRadius: 16),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(info.blurb,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            SizedBox(width: 96, child: _trailing(context)),
          ],
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    if (busy) {
      return const Center(
        child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (equipped) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: info.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpace.radiusSm),
          border: Border.all(color: info.color),
        ),
        child: Text('EQUIPPED',
            style: TextStyle(
                color: info.color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
      );
    }
    if (owned) {
      return GameButton(
        label: 'EQUIP',
        dense: true,
        gradient: const LinearGradient(
            colors: [AppColors.surfaceHigh, AppColors.surfaceHigh]),
        onPressed: onEquip,
      );
    }
    return GameButton(
      label: '${info.price}',
      icon: Icons.monetization_on,
      dense: true,
      gradient: AppColors.goldGradient,
      onPressed: canAfford ? onBuy : null,
    );
  }
}

class _ShopTile extends StatelessWidget {
  final String perk;
  final int price;
  final int ownedQty;
  final bool canAfford;
  final bool busy;
  final VoidCallback onBuy;

  const _ShopTile({
    required this.perk,
    required this.price,
    required this.ownedQty,
    required this.canAfford,
    required this.busy,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final info = perkInfos[perk];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: GamePanel(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            // Icon medallion with a soft glow.
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      blurRadius: 14),
                ],
              ),
              child: Icon(perkIcon(perk), color: Colors.black),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(perkName(perk),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (ownedQty > 0) ...[
                        const SizedBox(width: 6),
                        Text('×$ownedQty',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(info?.blurb ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            SizedBox(
              width: 92,
              child: GameButton(
                label: '$price',
                icon: Icons.monetization_on,
                dense: true,
                gradient: AppColors.goldGradient,
                onPressed: (canAfford && !busy) ? onBuy : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
