// map_service.dart — Abstract map interface. UI talks to THIS, never to Mapbox
// directly, so we can swap Mapbox -> MapLibre later without rewriting screens.

import '../models/turf.dart';

abstract class MapService {
  // TODO(phase1): center the map on a lng/lat and render the player's GPS dot.
  Future<void> centerOn({required double lng, required double lat});

  // Draw/update the active run's trail polyline.
  Future<void> drawTrail(List<List<double>> points);

  // Fill claimed loops (each a closed ring of [lng, lat]) in the player color.
  Future<void> drawClaims(List<List<List<double>>> rings);

  // TODO(phase4+): render other players' turf polygons in their owner colors.
  Future<void> drawTurf(List<Turf> turf);
}
