// Smoke tests for the app-open cinematic. The painter runs a lot of maths per
// frame (path metrics, clips, blurs); these step the whole sequence frame by
// frame so a bad value anywhere in the timeline surfaces here rather than on a
// player's first launch.

import 'package:claimr/features/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget harness(VoidCallback onDone) =>
      MaterialApp(home: SplashScreen(onDone: onDone));

  testWidgets('full cinematic paints every frame and completes', (t) async {
    SharedPreferences.setMockInitialValues({});

    var done = false;
    await t.pumpWidget(harness(() => done = true));
    await t.pump(); // let the prefs read resolve and the controller roll

    // Step through the entire 4.4s sequence. Any exception raised while
    // painting a frame fails the test on its own.
    for (var i = 0; i < 50; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }

    expect(done, isTrue, reason: 'onDone should fire when the cinematic ends');
  });

  // The cinematic is deliberately not gated behind a first-run flag: it plays
  // in full on every open. This guards that — a stray "seen" flag in prefs
  // must not shorten or skip it.
  testWidgets('plays in full on every launch, never short-cut', (t) async {
    SharedPreferences.setMockInitialValues({
      'splash_seen_v2': true,
      'onboarding_seen_v1': true,
    });

    var done = false;
    await t.pumpWidget(harness(() => done = true));
    await t.pump();

    // Past any plausible short cut, but well short of the full 4.4s.
    await t.pump(const Duration(milliseconds: 2000));
    expect(done, isFalse, reason: 'must still be playing the full cinematic');

    await t.pump(const Duration(milliseconds: 2600));
    expect(done, isTrue);
  });

  testWidgets('skip ends it immediately', (t) async {
    SharedPreferences.setMockInitialValues({});

    var done = false;
    await t.pumpWidget(harness(() => done = true));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600)); // let SKIP fade in

    await t.tap(find.text('SKIP  ▸'));
    await t.pump();
    expect(done, isTrue);
  });
}
