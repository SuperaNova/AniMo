// Mobile-specific implementation (no dart:js)
import 'package:flutter/foundation.dart';

/// Platform-specific implementation for mobile environment services.
///
/// Provides mobile-compatible implementations that don't rely on
/// web-specific APIs like dart:js.
class EnvironmentServicePlatform {
  /// Initializes Firebase for mobile platforms.
  ///
  /// This is a no-op since Firebase initialization on mobile is handled
  /// by Firebase.initializeApp() in the main app.
  /// The [config] parameter is kept for API compatibility with the web version.
  static void initializeFirebase(Map<String, dynamic> config) {
    // Firebase on mobile is initialized via Firebase.initializeApp() in main.dart
    // No additional work needed here
    if (!kIsWeb) {
      print('Mobile Firebase initialization handled by Firebase.initializeApp()');
    }
  }

  /// Loads Google Maps API for mobile platforms.
  ///
  /// This is a no-op since Maps on mobile is handled by native SDKs.
  /// The [apiKey] parameter is kept for API compatibility with the web version.
  static void loadGoogleMaps(String apiKey) {
    // Google Maps on mobile is handled via the Google Maps Flutter plugin
    // API key is set in AndroidManifest.xml or Info.plist
    if (!kIsWeb) {
      print('Mobile Google Maps handled by native SDKs');
    }
  }

  /// Checks if Google Maps is loaded on the mobile device.
  ///
  /// Always returns true on mobile as Maps availability is determined
  /// by the presence of the native plugin.
  static bool isGoogleMapsLoaded() {
    // On mobile, Maps availability is determined by the plugin
    return true;
  }
} 