// providers.dart — Shared Riverpod providers for the app's services.
// UI reads services from here so they stay swappable and testable.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/anticheat_service.dart';
import '../services/backend_service.dart';
import '../services/geometry_service.dart';
import '../services/location_service.dart';
import '../services/mapbox_map_service.dart';

// Typed to the interface so tests can swap in a fake GPS source.
final locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());

final mapServiceProvider =
    Provider<MapboxMapService>((ref) => MapboxMapService());

final geometryServiceProvider =
    Provider<GeometryService>((ref) => GeometryService());

final antiCheatServiceProvider =
    Provider<AntiCheatService>((ref) => AntiCheatService());

final backendServiceProvider =
    Provider<SupabaseBackendService>((ref) => SupabaseBackendService());

// True once Supabase keys are configured (so we can no-op gracefully without).
final backendEnabledProvider = Provider<bool>((ref) {
  final url = dotenv.env['SUPABASE_URL'];
  final key = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      dotenv.env['SUPABASE_ANON_KEY'];
  return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
});
