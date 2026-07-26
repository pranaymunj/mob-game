// pickup.dart — A power-up collectible on the map. Walk near it to grab a perk.

class Pickup {
  final String id;
  final double lng;
  final double lat;
  final String perk; // sprint | shield | wide_brush | recon

  const Pickup({
    required this.id,
    required this.lng,
    required this.lat,
    required this.perk,
  });
}
