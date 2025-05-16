import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines the possible roles a user can have within the application.
///
/// Each role has different permissions and access to different parts of the app:
/// - [farmer]: Can create and manage produce listings
/// - [buyer]: Can browse and purchase produce
/// - [driver]: Can access delivery functionality
/// - [admin]: Has administrative privileges
/// - [unknown]: Default role when role cannot be determined
enum UserRole { farmer, buyer, driver, admin, unknown }

/// Represents a user in the AniMo application.
///
/// Contains user information such as personal details, role, and preferences.
/// This model is used throughout the app to manage user authentication state
/// and access control.
class AppUser {
  /// Unique identifier for the user.
  final String uid;
  
  /// User's email address.
  final String? email;
  
  /// Display name of the user.
  final String? displayName;
  
  /// Phone number of the user.
  final String? phoneNumber;
  
  /// URL to the user's profile photo.
  final String? photoURL;
  
  /// The role of the user in the application.
  final UserRole role;
  
  /// Date when the user registered.
  final DateTime? registrationDate;
  
  /// Firebase Cloud Messaging token for sending notifications.
  final String? fcmToken;
  
  /// Date when the user profile was last updated.
  final DateTime? updatedAt;
  
  /// Default delivery location stored as coordinates and address information.
  final Map<String, dynamic>? defaultDeliveryLocation;

  /// Creates a new [AppUser] instance.
  ///
  /// The [uid] and [role] parameters are required, all others are optional.
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

  /// Creates an [AppUser] from Firestore document data.
  ///
  /// Converts Firestore document data into an AppUser instance.
  /// The [data] parameter contains the document fields, and [id] is the document ID.
  ///
  /// Returns an [AppUser] instance populated with data from Firestore.
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

  /// Converts this user object to a Firestore document.
  ///
  /// Creates a map of fields suitable for storing in Firestore.
  /// Only includes non-null fields to avoid storing unnecessary null values.
  ///
  /// Returns a Map containing the user data ready for Firestore.
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

  /// Creates a copy of this user with the specified fields replaced.
  ///
  /// Returns a new [AppUser] instance with updated fields while preserving
  /// the values of fields that are not specified.
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