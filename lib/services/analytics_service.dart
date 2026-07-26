// analytics_service.dart — Lightweight event + crash logging into Supabase.
//
// Deliberately fire-and-forget: analytics must never slow down or break
// gameplay, so every call swallows its own errors and is not awaited by
// callers. No third-party SDK, so there's nothing extra to configure.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  static bool _enabled = false;

  /// Called once at startup, after Supabase is initialised.
  static void enable() => _enabled = true;

  /// Log an event. Never throws, never blocks the caller.
  static void log(String name, [Map<String, dynamic>? props]) {
    if (!_enabled) return;
    unawaited(_send(name, props));
  }

  static Future<void> _send(String name, Map<String, dynamic>? props) async {
    try {
      await Supabase.instance.client.rpc('log_event', params: {
        'event_name': name,
        'event_props': props ?? const <String, dynamic>{},
      });
    } catch (_) {
      // Losing an analytics event is always preferable to disrupting the game.
    }
  }

  /// Route Flutter's error handlers here so crashes on a player's phone are
  /// visible to us instead of vanishing.
  static void captureErrors() {
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      log('error', {
        'message': details.exceptionAsString(),
        'library': details.library ?? 'flutter',
      });
      priorOnError?.call(details); // keep the console output in debug
    };

    // Errors that escape the Flutter framework (async, platform channels).
    PlatformDispatcher.instance.onError = (error, stack) {
      log('error', {
        'message': error.toString(),
        'library': 'platform',
      });
      return false; // false = still report to the default handler
    };
  }
}
