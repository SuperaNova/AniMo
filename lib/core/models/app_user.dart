import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { farmer, buyer, driver, admin, unknown }

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final UserRole role;
  final DateTime? registrationDate;
  final String? fcmToken;
  final DateTime? updatedAt;
  final Map<String, dynamic>? defaultDeliveryLocation;

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.role,
    this.registrationDate,
    this.fcmToken,
    this.updatedAt,
    this.defaultDeliveryLocation,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    return AppUser(
      uid: id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      photoURL: data['photoURL'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.unknown,
      ),
      registrationDate: (data['registrationDate'] as Timestamp?)?.toDate(),
      fcmToken: data['fcmToken'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      defaultDeliveryLocation: data['defaultDeliveryLocation'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoURL != null) 'photoURL': photoURL,
      'role': role.name,
      if (registrationDate != null) 'registrationDate': Timestamp.fromDate(registrationDate!),
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (defaultDeliveryLocation != null) 'defaultDeliveryLocation': defaultDeliveryLocation,
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    UserRole? role,
    DateTime? registrationDate,
    String? fcmToken,
    DateTime? updatedAt,
    Map<String, dynamic>? defaultDeliveryLocation,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      registrationDate: registrationDate ?? this.registrationDate,
      fcmToken: fcmToken ?? this.fcmToken,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultDeliveryLocation: defaultDeliveryLocation ?? this.defaultDeliveryLocation,
    );
  }
} 