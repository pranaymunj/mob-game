// onboarding_screen.dart — the 60-second explainer.
//
// Shown on EVERY app open by product decision (see app.dart), not just the
// first run — so nothing here reads the seen-flag any more. The flag is still
// written, so that restoring first-run-only gating is a one-line change in
// app.dart rather than a change that quietly shows onboarding forever because
// no one was recording that it had been seen.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';

const _seenKey = 'onboarding_seen_v1';

Future<void> _markSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_seenKey, true);
}

class _Page {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const _Page(this.icon, this.title, this.body, this.color);
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_Page>[
    _Page(Icons.map, 'Claim the streets',
        'Claimr turns your city into a game board. Walk real streets to claim real territory.',
        Color(0xFF56B4E9)),
    _Page(Icons.directions_walk, 'Walk a loop',
        'Start a run and walk. Your trail draws behind you. Close the loop back to your start to capture everything inside.',
        Color(0xFF009E73)),
    _Page(Icons.flag, 'Take & defend turf',
        'Enclosed land becomes yours in your color. Overlap a rival’s turf to steal it. Climb the leaderboard by area.',
        Color(0xFFE69F00)),
    _Page(Icons.visibility, 'Stay safe',
        'Eyes up — watch your surroundings. We show turf, never people’s live location. Runs auto-pause at car speed.',
        Color(0xFFD55E00)),
  ];

  Future<void> _finish() async {
    await _markSeen();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: p.color,
                          child: Icon(p.icon, size: 56, color: Colors.black),
                        ),
                        const SizedBox(height: 32),
                        Text(p.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 16),
                        Text(p.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(isLast ? 'Start playing' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
