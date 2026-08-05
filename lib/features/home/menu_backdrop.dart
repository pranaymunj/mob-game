// menu_backdrop.dart — The main menu's background: the same aerial night-city
// photograph the app-open cinematic uses (assets/images/CREDITS.md).
//
// Reusing that one image rather than shipping a second is deliberate: it costs
// no extra bundle, and opening on a city and then landing on the same city
// makes the app feel like one piece instead of two screens that happen to
// share a colour.
//
// It is held well back and scrimmed twice — once overall, once top and bottom —
// because this sits under live UI. A background that competes with a HUD, a
// mission card and a primary CTA is worse than no background at all.
//
// Deliberately static. The artwork it replaced repainted continuously behind
// the menu, which is exactly the sort of idle battery drain that gets a
// walking game deleted.

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class MenuBackdrop extends StatelessWidget {
  const MenuBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The photograph, dimmed hard. If it ever fails to load, the menu
        // simply falls back to the app's own dark ground.
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            AppColors.background.withValues(alpha: 0.62),
            BlendMode.srcOver,
          ),
          child: Image.asset(
            'assets/images/night_city.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) =>
                const ColoredBox(color: AppColors.background),
          ),
        ),

        // Cool it toward the brand palette so it reads as Claimr's city rather
        // than as a stock photo behind a game.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.accentDeep.withValues(alpha: 0.20),
                AppColors.background.withValues(alpha: 0.10),
              ],
            ),
          ),
        ),

        // Anchor bands: the HUD sits at the top and the CTA at the bottom, and
        // both need ground far darker than the middle of the frame.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xE6070A11),
                Color(0x66070A11),
                Color(0x99070A11),
                Color(0xF2070A11),
              ],
              stops: [0.0, 0.28, 0.62, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
