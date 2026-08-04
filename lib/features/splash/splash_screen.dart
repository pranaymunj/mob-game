// splash_screen.dart — Professional animated app-open built on a Lottie hero
// animation (designer-made, swappable at assets/anim/intro.json). The Lottie
// plays full-screen; the CLAIMR wordmark + tagline fade in over its final beat,
// then it hands off to the app. A Skip button is always offered, and if the
// animation asset is missing we fall back to a clean branded hold so the app
// never gets stuck.
//
// To change the animation: drop any Lottie JSON at assets/anim/intro.json.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lottie/lottie.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

const _introAsset = 'assets/anim/intro.json';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieCtrl; // driven by the composition
  late final AnimationController _brand; // wordmark/tagline reveal + fade
  bool _finished = false;
  bool? _hasAsset; // null = checking

  @override
  void initState() {
    super.initState();
    _lottieCtrl = AnimationController(vsync: this);
    _brand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _checkAsset();
  }

  Future<void> _checkAsset() async {
    bool ok;
    try {
      await rootBundle.load(_introAsset);
      ok = true;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _hasAsset = ok);
    if (!ok) {
      // No animation bundled — show a short branded hold, then continue.
      _brand.forward();
      Timer(const Duration(milliseconds: 3200), _finish);
    }
    // With an asset, playback is kicked off from Lottie's onLoaded.
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    _brand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A subtle brand-tinted vignette behind the animation.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [Color(0xFF161B29), AppColors.background],
              ),
            ),
          ),
          if (_hasAsset == true) _lottieLayer() else _fallbackHero(),
          _brandOverlay(),
          _skipButton(),
        ],
      ),
    );
  }

  Widget _lottieLayer() {
    return Center(
      child: Lottie.asset(
        _introAsset,
        controller: _lottieCtrl,
        fit: BoxFit.contain,
        onLoaded: (composition) {
          // Sync the controller to the animation's real length, then play.
          _lottieCtrl.duration = composition.duration;
          _lottieCtrl.forward().whenComplete(_finish);
          // Reveal the wordmark over the animation's final third.
          final ms = composition.duration.inMilliseconds;
          Timer(Duration(milliseconds: (ms * 0.55).round()), () {
            if (mounted) _brand.forward();
          });
        },
      ),
    );
  }

  // Shown only if assets/anim/intro.json is missing — keeps the app usable.
  Widget _fallbackHero() {
    return Center(
      child: AnimatedBuilder(
        animation: _brand,
        builder: (context, _) {
          final s = Curves.elasticOut.transform(_brand.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: 0.6 + 0.4 * s,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset('assets/app_icon.png', width: 110, height: 110),
            ),
          );
        },
      ),
    );
  }

  Widget _brandOverlay() {
    return AnimatedBuilder(
      animation: _brand,
      builder: (context, _) {
        final t = _brand.value;
        final rise = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
        return Align(
          alignment: const Alignment(0, 0.62),
          child: Opacity(
            opacity: rise,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - rise)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.appName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                            color: AppColors.accent.withValues(alpha: 0.7),
                            blurRadius: 26),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Claim the streets.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _skipButton() {
    return Positioned(
      right: 20,
      bottom: 30,
      child: SafeArea(
        child: TextButton(
          onPressed: _finish,
          child: Text(
            'SKIP  ▸',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
