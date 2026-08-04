// mapbox_map_service.dart — Concrete MapService backed by the Mapbox Flutter SDK.
// Wraps a MapboxMap controller (handed over once the MapWidget is created) so
// the rest of the app can move the camera / draw the trail without touching Mapbox.

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/photo_flag.dart';
import '../models/pickup.dart';
import '../models/turf.dart' as models;
import '../models/zone.dart';
import 'map_service.dart';

class MapboxMapService implements MapService {
  MapboxMap? _map;
  PolylineAnnotationManager? _trailGlowManager; // soft wide glow under the trail
  PolylineAnnotationManager? _trailManager;
  PolylineAnnotationManager? _ghostManager; // your best route (ghost run)
  PolygonAnnotationManager? _zoneManager; // Neighborhood Wars zone control
  PolygonAnnotationManager? _turfManager; // all players' persisted turf
  PolylineAnnotationManager? _turfOutlineManager; // styled turf borders
  PolylineAnnotationManager? _previewManager; // "close the loop" preview line
  PolygonAnnotationManager? _claimManager; // this session's live claims (mine)
  PointAnnotationManager? _ghostMarkerManager; // the moving 👻 marker
  PointAnnotation? _ghostMarker;
  PointAnnotationManager? _flagManager; // photo-flag 🚩 markers
  final Map<String, PhotoFlag> _flagByAnnotation = {};
  void Function(PhotoFlag)? onFlagTap;
  PointAnnotationManager? _pickupManager; // power-up 🎁 markers

  // Called from MapWidget.onMapCreated. Enables the puck and prepares the
  // annotation layers. Turf/claims are created first so the trail renders on
  // top of the filled polygons.
  Future<void> attach(MapboxMap map) async {
    _map = map;
    await map.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    _zoneManager = await map.annotations.createPolygonAnnotationManager();
    _turfManager = await map.annotations.createPolygonAnnotationManager();
    _turfOutlineManager = await map.annotations.createPolylineAnnotationManager();
    _previewManager = await map.annotations.createPolylineAnnotationManager();
    _claimManager = await map.annotations.createPolygonAnnotationManager();
    _ghostManager = await map.annotations.createPolylineAnnotationManager();
    // Glow layer is created BEFORE the trail so it renders underneath it,
    // giving the bright core a soft neon halo.
    _trailGlowManager = await map.annotations.createPolylineAnnotationManager();
    _trailManager = await map.annotations.createPolylineAnnotationManager();
    // Rounded caps + joins make the trail read as a smooth painted stroke
    // rather than a jagged chain of segments.
    await _trailGlowManager!.setLineCap(LineCap.ROUND);
    await _trailManager!.setLineCap(LineCap.ROUND);
    _ghostMarkerManager = await map.annotations.createPointAnnotationManager();
    _pickupManager = await map.annotations.createPointAnnotationManager();
    _flagManager = await map.annotations.createPointAnnotationManager();
    // ignore: deprecated_member_use
    _flagManager!.addOnPointAnnotationClickListener(_FlagClickListener(this));
  }

  // A dashed line from where you are back to your start — the loop you'd close.
  // Reuses the ghost-marker manager's sibling polyline layer for simplicity.
  Future<void> drawPreviewLine(List<double>? from, List<double>? to) async {
    final manager = _trailManager;
    if (manager == null) return;
    // Draw a faint straight guide segment as a separate short polyline on the
    // claim layer so it reads as "close here".
    await _previewManager?.deleteAll();
    if (from == null || to == null) return;
    await _previewManager?.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: [
        Position(from[0], from[1]),
        Position(to[0], to[1]),
      ]),
      lineColor: AppColors.go.toARGB32(),
      lineWidth: 3.0,
      lineOpacity: 0.7,
    ));
  }

  // Draw the tutorial's suggested loop as a bright dashed outline the player
  // can literally walk along. Uses the polyline manager so it reads as a route
  // to follow, not as claimed territory.
  Future<void> drawSuggestedLoop(List<List<double>> ring) async {
    final manager = _ghostManager; // reuse the guide-line layer
    if (manager == null || ring.length < 2) return;
    await manager.deleteAll();
    await manager.create(PolylineAnnotationOptions(
      geometry: LineString(
        coordinates: ring.map((p) => Position(p[0], p[1])).toList(),
      ),
      lineColor: AppColors.ownershipPalette[3].toARGB32(), // high-vis yellow
      lineWidth: 5.0,
      lineOpacity: 0.9,
    ));
  }

  Future<void> clearSuggestedLoop() async => _ghostManager?.deleteAll();

  // Draw power-up pickups as 🎁 markers.
  Future<void> drawPickups(List<Pickup> pickups) async {
    final manager = _pickupManager;
    if (manager == null) return;
    await manager.deleteAll();
    for (final p in pickups) {
      await manager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(p.lng, p.lat)),
        textField: '🎁',
        textSize: 24.0,
      ));
    }
  }

  // Draw photo flags as 🚩 markers; tapping one triggers [onFlagTap].
  Future<void> drawFlags(List<PhotoFlag> flags) async {
    final manager = _flagManager;
    if (manager == null) return;
    await manager.deleteAll();
    _flagByAnnotation.clear();
    for (final f in flags) {
      final ann = await manager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(f.lng, f.lat)),
        textField: '🚩',
        textSize: 26.0,
      ));
      _flagByAnnotation[ann.id] = f;
    }
  }

  void _handleFlagClick(PointAnnotation annotation) {
    final flag = _flagByAnnotation[annotation.id];
    if (flag != null) onFlagTap?.call(flag);
  }

  // Draw the saved best route as a faint gray "ghost" line to retrace.
  Future<void> drawGhostPath(List<List<double>> points) async {
    final manager = _ghostManager;
    if (manager == null || points.length < 2) return;
    await manager.deleteAll();
    await manager.create(PolylineAnnotationOptions(
      geometry: LineString(
        coordinates: points.map((p) => Position(p[0], p[1])).toList(),
      ),
      lineColor: 0xFF9E9E9E, // gray
      lineWidth: 4.0,
      lineOpacity: 0.7,
    ));
  }

  // Move the 👻 marker to a point along the ghost path (delete+recreate).
  Future<void> moveGhostMarker(List<double> point) async {
    final manager = _ghostMarkerManager;
    if (manager == null) return;
    if (_ghostMarker != null) {
      await manager.delete(_ghostMarker!);
      _ghostMarker = null;
    }
    _ghostMarker = await manager.create(PointAnnotationOptions(
      geometry: Point(coordinates: Position(point[0], point[1])),
      textField: '👻',
      textSize: 24.0,
    ));
  }

  Future<void> clearGhost() async {
    await _ghostManager?.deleteAll();
    await _ghostMarkerManager?.deleteAll();
    _ghostMarker = null;
  }

  @override
  Future<void> centerOn({required double lng, required double lat}) async {
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 16,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  @override
  Future<void> drawTrail(List<List<double>> points) async {
    final manager = _trailManager;
    final glow = _trailGlowManager;
    if (manager == null) return;

    // Redraw the whole trail each update. Cheap because updates are batched
    // (~every few meters), so the point count stays modest during a run.
    await manager.deleteAll();
    await glow?.deleteAll();
    if (points.length < 2) return;

    final coords = points.map((p) => Position(p[0], p[1])).toList();
    final line = LineString(coordinates: coords);

    // Neon look: a wide, soft, translucent halo underneath...
    await glow?.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: coords),
        lineColor: _playerColor,
        lineWidth: 18.0,
        lineBlur: 12.0,
        lineOpacity: 0.35,
      ),
    );
    // ...then a bright, crisp core stroke on top.
    await manager.create(
      PolylineAnnotationOptions(
        geometry: line,
        lineColor: _playerColor,
        lineWidth: 6.0,
        lineOpacity: 0.95,
      ),
    );
  }

  @override
  Future<void> drawClaims(List<List<List<double>>> rings) async {
    final manager = _claimManager;
    if (manager == null) return;

    await manager.deleteAll();
    final created = <PolygonAnnotation>[];
    for (final ring in rings) {
      final polygon = Polygon(
        coordinates: [ring.map((p) => Position(p[0], p[1])).toList()],
      );
      created.add(await manager.create(
        PolygonAnnotationOptions(
          geometry: polygon,
          fillColor: _playerColor,
          fillOpacity: 0.0, // starts invisible, then floods in
          fillOutlineColor: _playerColor,
        ),
      ));
    }
    // Flood the colour in with a bright over-shoot that settles — the fill
    // "claiming" the land is the visual heart of the game.
    _floodClaims(manager, created);
  }

  Future<void> _floodClaims(
      PolygonAnnotationManager manager, List<PolygonAnnotation> anns) async {
    // 0 -> 0.65 (over-shoot) -> 0.4 (settle), over ~600ms.
    const steps = [0.15, 0.35, 0.55, 0.65, 0.5, 0.4];
    for (final opacity in steps) {
      for (final a in anns) {
        a.fillOpacity = opacity;
        await manager.update(a);
      }
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
  }

  // Fill each controlled ~1km zone faintly in the controlling owner's color.
  Future<void> drawZones(List<Zone> zones) async {
    final manager = _zoneManager;
    if (manager == null) return;
    await manager.deleteAll();
    for (final z in zones) {
      final color = _hexToArgb(z.colorHex);
      await manager.create(PolygonAnnotationOptions(
        geometry: Polygon(
          coordinates: [z.ring.map((p) => Position(p[0], p[1])).toList()],
        ),
        fillColor: color,
        fillOpacity: 0.12, // faint tint so turf still reads on top
        fillOutlineColor: color,
      ));
    }
  }

  @override
  Future<void> drawTurf(List<models.Turf> turf) async {
    final manager = _turfManager;
    if (manager == null) return;

    await manager.deleteAll();
    await _turfOutlineManager?.deleteAll();
    for (final t in turf) {
      final color = _hexToArgb(t.colorHex);
      final polygon = Polygon(
        coordinates: [t.polygon.map((p) => Position(p[0], p[1])).toList()],
      );
      // Decay fade: fresh turf ~0.4 opacity, fading toward ~0.12 at 30 days.
      var fade = (0.4 - 0.28 * (t.ageDays / 30.0)).clamp(0.12, 0.4);
      // Higher-level turf reads richer: +~8% opacity per level above 1.
      fade = (fade + (t.level - 1) * 0.08).clamp(0.12, 0.7);

      // The owner's equipped turf style changes how their land reads on the
      // shared map — the one cosmetic other players actually see. Level also
      // thickens the border so a maxed-out territory looks fortified.
      final levelWidth = 1.0 + (t.level - 1) * 0.8;
      final (fillOpacity, lineWidth) = switch (t.style) {
        'turf_outline' => (fade * 0.4, 4.0 + levelWidth), // bold border
        'turf_glow' => ((fade * 1.4).clamp(0.0, 0.75), 2.5 + levelWidth),
        'turf_hatch' => (fade * 0.7, 3.0 + levelWidth),
        _ => (fade, levelWidth), // solid
      };

      await manager.create(
        PolygonAnnotationOptions(
          geometry: polygon,
          fillColor: color,
          fillOpacity: fillOpacity,
          fillOutlineColor: color,
        ),
      );
      // A separate outline stroke lets styles vary their border weight; Mapbox
      // polygons don't expose line width directly.
      if (lineWidth > 1.0) {
        final ring = t.polygon.map((p) => Position(p[0], p[1])).toList();
        await _turfOutlineManager?.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: ring),
          lineColor: color,
          lineWidth: lineWidth,
          lineOpacity: 0.9,
        ));
      }
    }
  }

  static int _hexToArgb(String hex) {
    final h = hex.replaceFirst('#', '');
    return int.parse('FF$h', radix: 16);
  }

  // The trail colour, driven by the equipped trail-skin cosmetic. Defaults to
  // the palette colour until a skin is applied.
  int _trailColor = AppColors
      .ownershipPalette[
          AppConstants.currentPlayerColorIndex % AppColors.ownershipPalette.length]
      .toARGB32();
  int get _playerColor => _trailColor;

  /// Apply the equipped cosmetic colours. Called when a run screen opens so the
  /// trail (and freshly-claimed turf) render in the player's chosen skin.
  void applyTrailColor(int argb) => _trailColor = argb;
}

// Routes 🚩 marker taps back to the service so the UI can show the photo.
// ignore: deprecated_member_use
class _FlagClickListener extends OnPointAnnotationClickListener {
  final MapboxMapService _service;
  _FlagClickListener(this._service);

  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    _service._handleFlagClick(annotation);
  }
}
