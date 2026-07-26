// crew.dart — A crew (team) and its pooled standings.

class Crew {
  final String id;
  final String name;
  final String colorHex;
  final int members;
  final double totalArea;

  const Crew({
    required this.id,
    required this.name,
    this.colorHex = '#0072B2',
    this.members = 0,
    this.totalArea = 0,
  });
}
