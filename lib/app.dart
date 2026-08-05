// app.dart — Root widget: theme + launch animation + first-run onboarding gate,
// then Home.

import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';

class ClaimrApp extends StatelessWidget {
  const ClaimrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _Root(),
    );
  }
}

// Flow: splash cinematic -> onboarding -> home, on EVERY app open.
//
// Both the cinematic and the onboarding cards replay each launch by product
// decision, rather than being gated behind a first-run flag. Both are
// skippable, so the fast path to Home stays two taps.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _splashDone = false;
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onDone: () => setState(() => _splashDone = true));
    }
    if (!_introDone) {
      return OnboardingScreen(onDone: () => setState(() => _introDone = true));
    }
    return const HomeScreen();
  }
}
