/// Represents geographical location data with optional address information.
///
/// Stores latitude and longitude coordinates along with additional address
/// details such as address hint, barangay, and municipality.
class LocationData {
  /// Latitude coordinate in decimal degrees.
  final double latitude;
  
  /// Longitude coordinate in decimal degrees.
  final double longitude;
  
  /// Optional descriptive hint about the address (e.g., "Near the town plaza").
  final String? addressHint;
  
  /// Optional barangay (village/district) name where the location is situated.
  final String? barangay;
  
  /// Optional municipality or city name where the location is situated.
  final String? municipality;

  /// Creates a new [LocationData] instance.
  ///
  /// The [latitude] and [longitude] parameters are required.
  /// The [addressHint], [barangay], and [municipality] parameters are optional.
  LocationData({
    required this.latitude,
    required this.longitude,
    this.addressHint,
    this.barangay,
    this.municipality,
  });

  /// Creates a [LocationData] from a map of values.
  ///
  /// Used to convert Firestore document data into a [LocationData] instance.
  /// If [map] is null, returns a default location with coordinates (0,0).
  ///
  /// Returns a [LocationData] instance populated with data from the map.
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

  /// Converts this location data to a map for Firestore storage.
  ///
  /// Creates a map representation of this object with non-null fields.
  ///
  /// Returns a Map containing the location data ready for Firestore.
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