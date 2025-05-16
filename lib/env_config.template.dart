// Environment configuration file TEMPLATE
// Copy this file to env_config.dart and fill in your API keys
// IMPORTANT: DO NOT commit env_config.dart to your repository!

/// Environment configuration for API keys and services.
///
/// Contains all sensitive configuration values used throughout the app.
/// This template should be copied to env_config.dart with actual values.
class EnvConfig {
  /// Firebase web application API key.
  static const String firebaseWebApiKey = 'YOUR_FIREBASE_WEB_API_KEY';
  
  /// Firebase Android application API key.
  static const String firebaseAndroidApiKey = 'YOUR_FIREBASE_ANDROID_API_KEY';
  
  /// Firebase project identifier.
  static const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';
  
  /// Firebase messaging sender ID.
  static const String firebaseMessagingSenderId = 'YOUR_FIREBASE_MESSAGING_SENDER_ID';
  
  /// Firebase web application ID.
  static const String firebaseWebAppId = 'YOUR_FIREBASE_WEB_APP_ID';
  
  /// Firebase Android application ID.
  static const String firebaseAndroidAppId = 'YOUR_FIREBASE_ANDROID_APP_ID';
  
  /// Firebase storage bucket URL.
  static const String firebaseStorageBucket = 'YOUR_FIREBASE_STORAGE_BUCKET';
  
  /// Firebase authentication domain.
  static const String firebaseAuthDomain = 'YOUR_FIREBASE_AUTH_DOMAIN';
  
  /// Firebase measurement ID for analytics.
  static const String firebaseMeasurementId = 'YOUR_FIREBASE_MEASUREMENT_ID';

  /// Google Maps API key for web platforms.
  static const String googleMapsWebApiKey = 'YOUR_GOOGLE_MAPS_WEB_API_KEY';
  
  /// Google Maps API key for directions service.
  static const String googleMapsDirectionsApiKey = 'YOUR_GOOGLE_MAPS_DIRECTIONS_API_KEY';
} 