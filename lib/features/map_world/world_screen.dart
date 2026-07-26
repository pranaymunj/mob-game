// world_screen.dart — The persistent shared map. Shows the real Mapbox map
// centered on your GPS, everyone's turf in their owner colors, photo flags, and
// updates live via Supabase realtime when turf anywhere changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../models/photo_flag.dart';

class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  String? _error;
  double? _lng, _lat; // last known center, for reloading on realtime events
  RealtimeChannel? _turfChannel;

  Future<void> _onMapCreated(MapboxMap map) async {
    final mapService = ref.read(mapServiceProvider);
    final location = ref.read(locationServiceProvider);

    await mapService.attach(map);
    mapService.onFlagTap = _showFlag; // tap a 🚩 to view its photo

    if (!await location.ensurePermission()) {
      setState(() => _error =
          'Location permission is off. Enable it in Settings to see your position.');
      return;
    }

    final here = await location.current();
    if (here != null) {
      _lng = here.lng;
      _lat = here.lat;
      await mapService.centerOn(lng: here.lng, lat: here.lat);
      await _loadTurf();
      await _loadZones();
      await _loadFlags();
      _subscribeRealtime();
    }
  }

  Future<void> _loadTurf() async {
    if (!ref.read(backendEnabledProvider) || _lng == null) return;
    final backend = ref.read(backendServiceProvider);
    await backend.signIn();
    final turf =
        await backend.turfNear(lng: _lng!, lat: _lat!, radiusMeters: 2000);
    await ref.read(mapServiceProvider).drawTurf(turf);
  }

  // Neighborhood Wars: fill each ~1km zone in its controlling owner's color.
  Future<void> _loadZones() async {
    if (!ref.read(backendEnabledProvider) || _lng == null) return;
    final zones = await ref
        .read(backendServiceProvider)
        .zonesNear(lng: _lng!, lat: _lat!, radiusMeters: 5000);
    await ref.read(mapServiceProvider).drawZones(zones);
  }

  Future<void> _loadFlags() async {
    if (!ref.read(backendEnabledProvider) || _lng == null) return;
    final flags = await ref
        .read(backendServiceProvider)
        .flagsNear(lng: _lng!, lat: _lat!, radiusMeters: 5000);
    await ref.read(mapServiceProvider).drawFlags(flags);
  }

  // Pick a photo and plant it as a flag at your current location.
  Future<void> _plantFlag() async {
    if (!ref.read(backendEnabledProvider)) return;
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final here = await ref.read(locationServiceProvider).current();
    if (here == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backendServiceProvider).addPhotoFlag(
            lng: here.lng,
            lat: here.lat,
            bytes: bytes,
          );
      await _loadFlags();
      messenger.showSnackBar(const SnackBar(content: Text('🚩 Flag planted!')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not plant flag: $e')));
    }
  }

  void _showFlag(PhotoFlag flag) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Image.network(flag.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Could not load image'),
                      )),
            ),
            if (flag.caption != null && flag.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(flag.caption!),
              ),
          ],
        ),
      ),
    );
  }

  void _subscribeRealtime() {
    if (!ref.read(backendEnabledProvider)) return;
    _turfChannel = ref.read(backendServiceProvider).subscribeTurf(() {
      if (mounted) {
        _loadTurf();
        _loadZones();
      }
    });
  }

  @override
  void dispose() {
    _turfChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      floatingActionButton: ref.watch(backendEnabledProvider)
          ? FloatingActionButton.extended(
              onPressed: _plantFlag,
              icon: const Text('🚩', style: TextStyle(fontSize: 18)),
              label: const Text('Plant flag'),
            )
          : null,
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('worldMap'),
            // Dark base map so the game matches its brand and turf colours pop,
            // instead of stock light Mapbox streets.
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
          ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Material(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
