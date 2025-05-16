import 'package:cloud_firestore/cloud_firestore.dart';
import './location_data.dart'; // For currentLocation and preferredServiceAreas

/// Current working status of a driver.
///
/// Represents the driver's real-time availability for accepting delivery tasks.
enum DriverAvailabilityStatus {
  /// Driver is online and ready to accept new delivery tasks.
  available, // Online and ready for tasks
  
  /// Driver is online but currently busy with a delivery task.
  on_delivery, // Online but currently busy with a task
  
  /// Driver is not working and unavailable for tasks.
  offline, // Not working
  
  /// Driver is online but temporarily not accepting new tasks (e.g., on break).
  unavailable, // Online but temporarily not taking tasks (e.g., on a break)
  
  /// Driver account has been suspended and cannot accept tasks.
  suspended, // Account issue
}

/// Converts a [DriverAvailabilityStatus] to its string representation.
///
/// Returns the name of the status enum value.
String driverAvailabilityStatusToString(DriverAvailabilityStatus status) {
  return status.name;
}

/// Converts a string to a [DriverAvailabilityStatus].
///
/// The [statusString] should match the name of a status enum value.
/// Returns the status value matching the string, or [DriverAvailabilityStatus.offline]
/// if no match is found.
DriverAvailabilityStatus driverAvailabilityStatusFromString(String? statusString) {
  return DriverAvailabilityStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => DriverAvailabilityStatus.offline,
      );
}

/// Administrative status of a driver's account.
///
/// Represents the longer-term status of a driver's account within the system.
enum DriverAccountStatus {
  /// Account is awaiting approval from administrators.
  pending_approval,
  
  /// Account is active and can be used normally.
  active,
  
  /// Account is temporarily suspended due to policy violations or other issues.
  suspended,
  
  /// Account has been permanently deactivated.
  deactivated,
}

/// Converts a [DriverAccountStatus] to its string representation.
///
/// Returns the name of the status enum value.
String driverAccountStatusToString(DriverAccountStatus status) {
  return status.name;
}

/// Converts a string to a [DriverAccountStatus].
///
/// The [statusString] should match the name of a status enum value.
/// Returns the status value matching the string, or [DriverAccountStatus.pending_approval]
/// if no match is found.
DriverAccountStatus driverAccountStatusFromString(String? statusString) {
  return DriverAccountStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => DriverAccountStatus.pending_approval,
      );
}


/// Represents a delivery driver in the system.
///
/// Contains driver profile information, vehicle details, location data,
/// availability status, and performance metrics. This model tracks
/// all aspects of a driver's activity in the platform.
class Driver {
  /// Unique identifier for the driver (matches Firebase Auth UID).
  final String id; // Document ID (should be same as Firebase Auth UID)
  
  /// Display name of the driver.
  final String? displayName;
  
  /// Verified phone number of the driver.
  final String? phoneNumber; // Should be verified
  
  /// URL to the driver's profile photo.
  final String? profilePhotoUrl;

  /// Type of vehicle the driver operates (e.g., "Tricycle").
  final String? vehicleType; // e.g., "Tricycle", "Motorcycle_with_sidecar"
  
  /// License plate number of the driver's vehicle.
  final String? vehiclePlateNumber;
  
  /// Notes about the cargo capacity of the driver's vehicle.
  final String? vehicleCapacityNotes; // e.g., "Can carry up to 5 kaings"

  /// Current geographical location of the driver.
  final LocationData? currentLocation; // Updated periodically by driver's app
  
  /// Timestamp when the current location was last updated.
  final Timestamp? currentLocationTimestamp;
  
  /// Whether the driver is currently online in the app.
  final bool isOnline; // Simplified overall online status
  
  /// Detailed status of the driver's availability for tasks.
  final DriverAvailabilityStatus availabilityStatus; // More granular status

  // For the Platform-Guaranteed Farmer Payment model where driver remits to platform
  /// Amount the driver needs to remit to the platform from completed deliveries.
  final double? currentBalanceOwedToPlatform; // Amount driver needs to remit
  
  /// Last date when the driver remitted payment to the platform.
  final Timestamp? lastRemittanceDateToPlatform;


  // We might not use preferredServiceAreas for MVP to keep matching simpler
  // final List<LocationData>? preferredServiceAreas; 

  /// Average rating of the driver from 1-5 stars.
  final double? ratingsAverage;
  
  /// Total number of ratings the driver has received.
  final int? ratingsCount;

  /// Date when the driver registered on the platform.
  final Timestamp registrationDate;
  
  /// Date and time of the driver's last login.
  final Timestamp? lastLogin;
  
  /// Version of the app the driver is using.
  final String? appVersion;
  
  /// Device token for sending push notifications.
  final String? deviceToken; // For FCM push notifications

  /// Administrative status of the driver's account.
  final DriverAccountStatus accountStatus;
  
  /// Total number of deliveries the driver has completed.
  final int? totalDeliveriesCompleted;
  
  // Earnings might be tracked separately or via an aggregated view, not directly stored here for simplicity.
  // final double? earningsToDate; 

  /// Creates a new [Driver] instance.
  ///
  /// The [id], [availabilityStatus], [registrationDate], and [accountStatus]
  /// parameters are required. All other parameters are optional.
  Driver({
    required this.id,
    this.displayName,
    this.phoneNumber,
    this.profilePhotoUrl,
    this.vehicleType,
    this.vehiclePlateNumber,
    this.vehicleCapacityNotes,
    this.currentLocation,
    this.currentLocationTimestamp,
    this.isOnline = false,
    required this.availabilityStatus,
    this.currentBalanceOwedToPlatform,
    this.lastRemittanceDateToPlatform,
    this.ratingsAverage,
    this.ratingsCount,
    required this.registrationDate,
    this.lastLogin,
    this.appVersion,
    this.deviceToken,
    required this.accountStatus,
    this.totalDeliveriesCompleted,
  });

  /// Creates a [Driver] from a Firestore document snapshot.
  ///
  /// Converts Firestore document data into a Driver instance.
  /// The [doc] parameter contains the document snapshot.
  ///
  /// Returns a [Driver] instance populated with data from Firestore.
  factory Driver.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Driver(
      id: doc.id,
      displayName: data['displayName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      vehicleType: data['vehicleType'] as String?,
      vehiclePlateNumber: data['vehiclePlateNumber'] as String?,
      vehicleCapacityNotes: data['vehicleCapacityNotes'] as String?,
      currentLocation: data['currentLocation'] != null 
          ? LocationData.fromMap(data['currentLocation'] as Map<String, dynamic>) 
          : null,
      currentLocationTimestamp: data['currentLocationTimestamp'] as Timestamp?,
      isOnline: data['isOnline'] as bool? ?? false,
      availabilityStatus: driverAvailabilityStatusFromString(data['availabilityStatus'] as String?),
      currentBalanceOwedToPlatform: (data['currentBalanceOwedToPlatform'] as num?)?.toDouble(),
      lastRemittanceDateToPlatform: data['lastRemittanceDateToPlatform'] as Timestamp?,
      ratingsAverage: (data['ratingsAverage'] as num?)?.toDouble(),
      ratingsCount: data['ratingsCount'] as int?,
      registrationDate: data['registrationDate'] as Timestamp? ?? Timestamp.now(),
      lastLogin: data['lastLogin'] as Timestamp?,
      appVersion: data['appVersion'] as String?,
      deviceToken: data['deviceToken'] as String?,
      accountStatus: driverAccountStatusFromString(data['accountStatus'] as String?),
      totalDeliveriesCompleted: data['totalDeliveriesCompleted'] as int?,
    );
  }

  /// Converts this driver to a map for Firestore storage.
  ///
  /// Creates a map representation with non-null fields for storing in Firestore.
  ///
  /// Returns a Map containing the driver data ready for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      if (displayName != null) 'displayName': displayName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (vehiclePlateNumber != null) 'vehiclePlateNumber': vehiclePlateNumber,
      if (vehicleCapacityNotes != null) 'vehicleCapacityNotes': vehicleCapacityNotes,
      if (currentLocation != null) 'currentLocation': currentLocation!.toMap(),
      if (currentLocationTimestamp != null) 'currentLocationTimestamp': currentLocationTimestamp,
      'isOnline': isOnline,
      'availabilityStatus': driverAvailabilityStatusToString(availabilityStatus),
      if (currentBalanceOwedToPlatform != null) 'currentBalanceOwedToPlatform': currentBalanceOwedToPlatform,
      if (lastRemittanceDateToPlatform != null) 'lastRemittanceDateToPlatform': lastRemittanceDateToPlatform,
      if (ratingsAverage != null) 'ratingsAverage': ratingsAverage,
      if (ratingsCount != null) 'ratingsCount': ratingsCount,
      'registrationDate': registrationDate,
      if (lastLogin != null) 'lastLogin': lastLogin,
      if (appVersion != null) 'appVersion': appVersion,
      if (deviceToken != null) 'deviceToken': deviceToken,
      'accountStatus': driverAccountStatusToString(accountStatus),
      if (totalDeliveriesCompleted != null) 'totalDeliveriesCompleted': totalDeliveriesCompleted,
    };
  }
} 