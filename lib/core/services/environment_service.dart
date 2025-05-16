import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../env_config.dart';

// Import dart:js only on web platform
import 'environment_service_web.dart' if (dart.library.io) 'environment_service_mobile.dart';

/// Service to handle environment-specific configurations.
///
/// Manages initialization of platform-specific services like Firebase and
/// Google Maps based on the current platform (web or mobile).
class EnvironmentService {
  /// Initializes web-specific configurations.
  ///
  /// Sets up Firebase configuration and loads Google Maps API for web platforms.
  /// Silently handles initialization errors to prevent app crashes.
  static void initializeWebConfig() {
    if (kIsWeb) {
      try {
        // Initialize Firebase config in the web
        final firebaseConfig = {
          'apiKey': EnvConfig.firebaseWebApiKey,
          'authDomain': EnvConfig.firebaseAuthDomain,
          'projectId': EnvConfig.firebaseProjectId,
          'storageBucket': EnvConfig.firebaseStorageBucket,
          'messagingSenderId': EnvConfig.firebaseMessagingSenderId,
          'appId': EnvConfig.firebaseWebAppId,
          'measurementId': EnvConfig.firebaseMeasurementId,
        };
        
        // Use the platform-specific implementation
        EnvironmentServicePlatform.initializeFirebase(firebaseConfig);
        
        // Load Google Maps API dynamically for web only
        EnvironmentServicePlatform.loadGoogleMaps(EnvConfig.googleMapsWebApiKey);
      } catch (e) {
        print('Error initializing web config: $e');
        // Continue app initialization even if web config fails
      }
    }
  }
  
  /// Initializes Android-specific configurations.
  ///
  /// Performs any Android-specific setup required for the app.
  /// Returns a [Future] that completes when initialization is done.
  static Future<void> initializeAndroidConfig() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // You could add Android-specific initialization here
      // For example, you might need to set API keys for certain native plugins
    }
  }
  
  /// Initializes all environment configurations.
  ///
  /// Detects the current platform and calls the appropriate initialization
  /// methods. Handles errors gracefully to ensure app startup isn't blocked.
  /// Returns a [Future] that completes when all initialization is complete.
  static Future<void> initialize() async {
    try {
      // Web specific initialization
      if (kIsWeb) {
        initializeWebConfig();
      }
      
      // Android specific initialization
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await initializeAndroidConfig();
      }
    } catch (e) {
      print('Environment initialization error: $e');
      // Continue app initialization even if environment setup fails
    }
  }
} 