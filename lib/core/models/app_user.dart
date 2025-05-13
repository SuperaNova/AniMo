import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { farmer, buyer, driver, unknown }

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.farmer:
      return 'farmer';
    case UserRole.buyer:
      return 'buyer';
    case UserRole.driver:
      return 'driver';
    default:
      return 'unknown';
  }
}

UserRole userRoleFromString(String? roleString) {
  if (roleString == 'farmer') {
    return UserRole.farmer;
  } else if (roleString == 'buyer') {
    return UserRole.buyer;
  } else if (roleString == 'driver') {
    return UserRole.driver;
  }
  return UserRole.unknown;
}

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final UserRole role;
  final Timestamp registrationDate;
  // Add other common fields if needed, e.g., deviceToken for FCM

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.role,
    required this.registrationDate,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      photoURL: data['photoURL'] as String?,
      role: userRoleFromString(data['role'] as String?),
      registrationDate: data['registrationDate'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // uid is the document ID, so not stored in fields typically
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoURL != null) 'photoURL': photoURL,
      'role': userRoleToString(role),
      'registrationDate': registrationDate,
    };
  }
} 