// theme.dart — Design system: colours, gradients, elevation, radii, and a
// game-styled ThemeData. The goal is a cohesive look — chunky rounded panels,
// depth, and glow accents — rather than default flat Material.
//
// The player-ownership palette is colourblind-safe (Okabe–Ito / Wong 2011),
// so turf ownership never relies on colour alone (CLAUDE.md Part 5).

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand / surface — layered, warmer, with headroom for chunky framed panels.
  static const Color background = Color(0xFF11151F);
  static const Color surface = Color(0xFF232C40); // panel face (top of gradient)
  static const Color surfaceLow = Color(0xFF19202F); // panel bottom / recesses
  static const Color surfaceHigh = Color(0xFF2E384F); // raised elements
  static const Color onSurface = Color(0xFFF3F6FC);
  static const Color muted = Color(0xFF97A2BA); // secondary text

  // Three-colour system to kill the old monochrome feel:
  //   green  = go / primary action    gold = economy / rewards    blue = brand
  static const Color go = Color(0xFF3DD97E); // primary CTA (Start, confirm)
  static const Color goDeep = Color(0xFF23A55A); // its 3D base/lip
  static const Color accent = Color(0xFF4EA9FF); // brand blue
  static const Color accentDeep = Color(0xFF2A6FD6);
  static const Color gold = Color(0xFFF3B01C); // coins / buy
  static const Color goldDeep = Color(0xFFB9820E); // gold 3D base/lip
  static const Color danger = Color(0xFFEF5364);

  // Darken a colour for a 3D button's bottom "lip".
  static Color darken(Color c, [double amount = 0.28]) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  // Colourblind-safe ownership palette (Okabe–Ito).
  static const List<Color> ownershipPalette = <Color>[
    Color(0xFFE69F00), // orange
    Color(0xFF56B4E9), // sky blue
    Color(0xFF009E73), // bluish green
    Color(0xFFF0E442), // yellow
    Color(0xFF0072B2), // blue
    Color(0xFFD55E00), // vermillion
    Color(0xFFCC79A7), // reddish purple
  ];

  // A top-lit gradient for chunky framed panels — stronger than before so the
  // depth reads at a glance.
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceHigh, surfaceLow],
  );

  // Button face gradients (the top surface of a 3D button).
  static const LinearGradient goGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF57E895), go],
  );
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6FBBFF), accent],
  );
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFD35C), gold],
  );
}

// Spacing / radius scale — one source of truth so layouts stay consistent.
class AppSpace {
  AppSpace._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static const double radius = 18; // default panel corner
  static const double radiusSm = 12;
  static const double radiusLg = 26;
}

// Reusable soft shadow so raised surfaces feel consistent.
List<BoxShadow> softShadow({double blur = 18, double y = 8, double a = 0.35}) =>
    [BoxShadow(color: Colors.black.withValues(alpha: a), blurRadius: blur, offset: Offset(0, y))];

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      primary: AppColors.accent,
      secondary: AppColors.gold,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      // One typeface everywhere — the fastest single lever for "this is a game"
      // rather than "this is a stock Material app".
      fontFamily: 'Baloo2',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.radius),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          // Height floor only — Size.fromHeight() forces infinite min width,
          // which crashes buttons in a Row (learned the hard way).
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpace.radiusSm),
          ),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpace.radiusSm),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(
            color: AppColors.onSurface, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpace.radiusSm)),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.accent,
        labelColor: AppColors.onSurface,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        dividerColor: Colors.transparent,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
      // A consistent, gentle push transition on every screen instead of the
      // platform default — a quick fade + rise reads as "designed".
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: _FadeRiseTransitions(),
        TargetPlatform.android: _FadeRiseTransitions(),
      }),
    );
  }
}

class _FadeRiseTransitions extends PageTransitionsBuilder {
  const _FadeRiseTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
