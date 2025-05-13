
// Helper class for GeoPoint-like structure
class LocationData {
  final double latitude;
  final double longitude;
  final String? addressHint;
  final String? barangay;
  final String? municipality;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.addressHint,
    this.barangay,
    this.municipality,
  });

  // Factory constructor to create LocationData from a map (Firestore data)
  factory LocationData.fromMap(Map<String, dynamic>? map) {
    // Provide default values or handle null map cases gracefully
    if (map == null) {
      // Consider logging this case or returning a pre-defined 'unknown' location
      return LocationData(latitude: 0.0, longitude: 0.0, addressHint: 'Unknown address');
    }
    return LocationData(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      addressHint: map['addressHint'] as String?,
      barangay: map['barangay'] as String?,
      municipality: map['municipality'] as String?,
    );
  }

  // Method to convert LocationData to a map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (addressHint != null) 'addressHint': addressHint,
      if (barangay != null) 'barangay': barangay,
      if (municipality != null) 'municipality': municipality,
    };
  }

  // Optional: A method to represent LocationData as a GeoPoint for direct use with Firestore GeoPoint type if preferred
  // GeoPoint toGeoPoint() {
  //   return GeoPoint(latitude, longitude);
  // }

  // Optional: Factory to create from GeoPoint if you decide to store as GeoPoint in Firestore
  // factory LocationData.fromGeoPoint(GeoPoint geoPoint, {String? addressHint, String? barangay, String? municipality}) {
  //   return LocationData(
  //     latitude: geoPoint.latitude,
  //     longitude: geoPoint.longitude,
  //     addressHint: addressHint,
  //     barangay: barangay,
  //     municipality: municipality,
  //   );
  // }
} 