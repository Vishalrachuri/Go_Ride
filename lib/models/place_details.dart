// lib/models/place_details.dart

class PlaceDetails {
  final String placeId;
  final String name;
  final double lat;
  final double lng;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'lat': lat,
      'lng': lng,
    };
  }

  factory PlaceDetails.fromMap(Map<String, dynamic> map) {
    return PlaceDetails(
      placeId: map['placeId'],
      name: map['name'],
      lat: map['lat'],
      lng: map['lng'],
    );
  }
}