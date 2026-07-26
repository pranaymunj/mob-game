// photo_flag.dart — A photo left at a real-world spot on the map.

class PhotoFlag {
  final String id;
  final String ownerId;
  final double lng;
  final double lat;
  final String url;
  final String? caption;

  const PhotoFlag({
    required this.id,
    required this.ownerId,
    required this.lng,
    required this.lat,
    required this.url,
    this.caption,
  });
}
