// zone.dart — A ~1km grid cell ("neighborhood") controlled by one owner.
// cx/cy are the cell indices; the cell spans [cx*step, (cx+1)*step] in lng and
// [cy*step, (cy+1)*step] in lat.

class Zone {
  static const double step = 0.01; // ~1 km cell

  final int cx;
  final int cy;
  final String ownerId;
  final String colorHex; // controlling owner's color
  final double area;

  const Zone({
    required this.cx,
    required this.cy,
    required this.ownerId,
    required this.colorHex,
    required this.area,
  });

  // The cell's corner ring as [lng, lat] points (closed).
  List<List<double>> get ring {
    final x0 = cx * step, x1 = (cx + 1) * step;
    final y0 = cy * step, y1 = (cy + 1) * step;
    return [
      [x0, y0],
      [x1, y0],
      [x1, y1],
      [x0, y1],
      [x0, y0],
    ];
  }
}
