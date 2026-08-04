// splash_screen.dart — Animated launch screen. The icon scales + fades in, the
// wordmark rises, and a claim "ripple" expands, then we hand off to the app.

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<double> _ripple;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _iconScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );
    _iconFade = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.3));
    _ripple = CurvedAnimation(parent: _c, curve: const Interval(0.3, 0.9, curve: Curves.easeOut));
    _textFade = CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.75));
    _textSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.8, curve: Curves.easeOut)),
    );

    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Expanding "claim" ripple in the player color.
                    Container(
                      width: 220 * _ripple.value,
                      height: 220 * _ripple.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent
                            .withValues(alpha: 0.25 * (1 - _ripple.value)),
                      ),
                    ),
                    // App icon.
                    Opacity(
                      opacity: _iconFade.value,
                      child: Transform.scale(
                        scale: _iconScale.value,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset('assets/app_icon.png',
                              width: 128, height: 128),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      Text(
                        AppConstants.appName.toUpperCase(),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.6),
                                    blurRadius: 22),
                              ],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text('Claim the streets.',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
