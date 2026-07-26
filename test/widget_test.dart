// widget_test.dart — Smoke test: the home screen renders with its four buttons.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:claimr/core/theme.dart';
import 'package:claimr/features/home/home_screen.dart';

void main() {
  testWidgets('Main menu shows the Start Run CTA and nav destinations',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    // The menu animates (backdrop + CTA glow), so settle a frame rather than
    // pumpAndSettle — the animations repeat forever.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('START RUN'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Ranks'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
