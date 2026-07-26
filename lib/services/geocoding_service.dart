// geocoding_service.dart — Reverse-geocode a claim's location into a
// neighbourhood name via the Mapbox Geocoding API, so a capture can say
// "You claimed turf in Bandra!". Uses the existing public token; fails soft
// (returns null) so it never disrupts a capture.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeocodingService {
  // Prefer the most local label available, falling back to broader areas.
  static const _types = 'neighborhood,locality,place';

  Future<String?> districtFor(double lng, double lat) async {
    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      '$lng,$lat.json?types=$_types&limit=1&access_token=$token',
    );

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      final features = (jsonDecode(body) as Map)['features'] as List?;
      if (features == null || features.isEmpty) return null;
      final name = (features.first as Map)['text'];
      return name is String && name.isNotEmpty ? name : null;
    } catch (_) {
      return null; // network/geocode failure must never break a capture
    }
  }
}
