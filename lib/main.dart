// main.dart — Entry point. Loads secrets from .env, initializes Mapbox +
// Supabase, then runs the app inside a Riverpod ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Secrets live in .env (gitignored), never hardcoded (CLAUDE.md Part 6).
  await dotenv.load(fileName: '.env');

  final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
  if (token != null && token.isNotEmpty) {
    MapboxOptions.setAccessToken(token);
  }

  // Initialize Supabase only if keys are present, so the app still boots
  // during earlier phases / before the backend is configured.
  final supaUrl = dotenv.env['SUPABASE_URL'];
  final supaKey =
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];
  if (supaUrl != null && supaUrl.isNotEmpty && supaKey != null && supaKey.isNotEmpty) {
    // New keys look like "sb_publishable_..."; legacy keys are JWTs ("eyJ...").
    final isPublishable = supaKey.startsWith('sb_');
    await Supabase.initialize(
      url: supaUrl,
      publishableKey: isPublishable ? supaKey : null,
      // ignore: deprecated_member_use — legacy JWT anon keys still supported
      anonKey: isPublishable ? null : supaKey,
    );
    // Analytics + crash capture need Supabase, so enable them here.
    AnalyticsService.enable();
    AnalyticsService.captureErrors();
    AnalyticsService.log('app_open');
  }

  // Prepare notifications, but do NOT prompt here — permission is requested
  // after the player's first claim (see run_screen).
  try {
    await NotificationService().init();
  } catch (_) {}

  runApp(const ProviderScope(child: ClaimrApp()));
}
