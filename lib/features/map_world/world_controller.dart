// world_controller.dart — Logic for the persistent world map view.
// Phase 0: stub holding the turf list. Phase 4/5: loads turf near the
// viewport + realtime updates.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/turf.dart';

class WorldTurfController extends Notifier<List<Turf>> {
  @override
  List<Turf> build() => const [];

  // TODO(phase4/5): replace with turf loaded near the viewport (ST_DWithin).
  void setTurf(List<Turf> turf) => state = turf;
}

final worldTurfProvider =
    NotifierProvider<WorldTurfController, List<Turf>>(WorldTurfController.new);
