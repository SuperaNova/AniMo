import 'package:cloud_firestore/cloud_firestore.dart';
import './location_data.dart'; // For currentLocation and preferredServiceAreas

enum DriverAvailabilityStatus {
  available, // Online and ready for tasks
  on_delivery, // Online but currently busy with a task
  offline, // Not working
  unavailable, // Online but temporarily not taking tasks (e.g., on a break)
  suspended, // Account issue
}

String driverAvailabilityStatusToString(DriverAvailabilityStatus status) {
  return status.name;
}

DriverAvailabilityStatus driverAvailabilityStatusFromString(String? statusString) {
  return DriverAvailabilityStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => DriverAvailabilityStatus.offline,
      );
}

enum DriverAccountStatus {
  pending_approval,
  active,
  suspended,
  deactivated,
}

String driverAccountStatusToString(DriverAccountStatus status) {
  return status.name;
}

DriverAccountStatus driverAccountStatusFromString(String? statusString) {
  return DriverAccountStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => DriverAccountStatus.pending_approval,
      );
}


class Driver {
  final String id; // Document ID (should be same as Firebase Auth UID)
  final String? displayName;
  final String? phoneNumber; // Should be verified
  final String? profilePhotoUrl;

  final String? vehicleType; // e.g., "Tricycle", "Motorcycle_with_sidecar"
  final String? vehiclePlateNumber;
  final String? vehicleCapacityNotes; // e.g., "Can carry up to 5 kaings"

  final LocationData? currentLocation; // Updated periodically by driver's app
  final Timestamp? currentLocationTimestamp;
  
  final bool isOnline; // Simplified overall online status
  final DriverAvailabilityStatus availabilityStatus; // More granular status

  // For the Platform-Guaranteed Farmer Payment model where driver remits to platform
  final double? currentBalanceOwedToPlatform; // Amount driver needs to remit
  final Timestamp? lastRemittanceDateToPlatform;


  // We might not use preferredServiceAreas for MVP to keep matching simpler
  // final List<LocationData>? preferredServiceAreas; 

  final double? ratingsAverage;
  final int? ratingsCount;

  final Timestamp registrationDate;
  final Timestamp? lastLogin;
  final String? appVersion;
  final String? deviceToken; // For FCM push notifications

  final DriverAccountStatus accountStatus;
  final int? totalDeliveriesCompleted;
  
  // Earnings might be tracked separately or via an aggregated view, not directly stored here for simplicity.
  // final double? earningsToDate; 

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