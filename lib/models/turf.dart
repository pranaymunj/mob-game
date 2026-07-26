// turf.dart — A claimed polygon of real-world territory owned by a player.
// `polygon` is a list of [lng, lat] points (GeoJSON order) forming a ring.
// `colorHex` is the owner's display color (e.g. '#56B4E9') for rendering.

class Turf {
  final String id;
  final String ownerId;
  final List<List<double>> polygon; // ring of [lng, lat] points
  final double area; // square meters
  final DateTime claimedAt;
  final String colorHex;
  final int ageDays; // days since last active (for decay fade)
  final String style; // owner's equipped turf style (turf_solid/outline/…)
  final int level; // 1..5, raised by re-walking your own turf

  const Turf({
    required this.id,
    required this.ownerId,
    required this.polygon,
    required this.area,
    required this.claimedAt,
    this.colorHex = '#56B4E9',
    this.ageDays = 0,
    this.style = 'turf_solid',
    this.level = 1,
  });
}
