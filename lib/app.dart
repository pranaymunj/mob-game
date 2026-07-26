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

// Flow: splash animation -> (first run) onboarding -> home.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _splashDone = false;
  bool? _seen; // null = still loading the onboarding flag

  @override
  void initState() {
    super.initState();
    // Load the onboarding flag while the splash animates.
    hasSeenOnboarding().then((v) {
      if (mounted) setState(() => _seen = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone || _seen == null) {
      return SplashScreen(onDone: () => setState(() => _splashDone = true));
    }
    if (_seen == false) {
      return OnboardingScreen(onDone: () => setState(() => _seen = true));
    }
    return const HomeScreen();
  }
}
