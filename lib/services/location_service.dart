// location_service.dart — GPS position + speed stream via geolocator.
// Handles permission, one-shot current position, and a batched update stream
// (~every few meters / seconds) to keep cost + battery down (CLAUDE.md Part 5).

import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

class GpsSample {
  final double lng;
  final double lat;
  final double speedMps;
  final double accuracy; // horizontal accuracy in meters (smaller = better)
  final DateTime at;
  const GpsSample({
    required this.lng,
    required this.lat,
    required this.speedMps,
    required this.accuracy,
    required this.at,
  });

  factory GpsSample.fromPosition(Position p) => GpsSample(
        lng: p.longitude,
        lat: p.latitude,
        speedMps: p.speed, // meters/second from the OS
        accuracy: p.accuracy,
        at: p.timestamp,
      );
}

abstract class LocationService {
  Future<bool> ensurePermission();
  Future<GpsSample?> current();
  Stream<GpsSample> positions();
}

class GeolocatorLocationService implements LocationService {
  // Ask for permission, returning true only if we may read location.
  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  @override
  Future<GpsSample?> current() async {
    if (!await ensurePermission()) return null;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GpsSample.fromPosition(p);
  }

  @override
  Stream<GpsSample> positions() {
    return Geolocator.getPositionStream(locationSettings: _runSettings())
        .map(GpsSample.fromPosition);
  }

  // Location settings for an active run. The critical part is background
  // tracking: without it iOS suspends the app the moment the screen locks and
  // the trail simply stops — which makes the game unplayable with the phone in
  // a pocket, and contradicts our own "eyes up" safety advice.
  //
  // bestForNavigation gives the highest-accuracy fixes; distanceFilter batches
  // updates so we only emit after ~4m of movement (cost + jitter control).
  LocationSettings _runSettings() {
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
        // Tells iOS this is a fitness activity so it tunes the GPS behaviour.
        activityType: ActivityType.fitness,
        // iOS would otherwise auto-pause updates when it thinks you've stopped,
        // which silently kills a run when you wait at a crossing.
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        // Shows the blue status-bar pill so the player always knows we're
        // tracking — required for honesty with "When In Use" permission.
        showBackgroundLocationIndicator: true,
      );
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
        // Android needs a visible foreground service to keep GPS alive.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Claimr is recording your run',
          notificationText: 'Your trail is being tracked',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 4,
    );
  }
}
