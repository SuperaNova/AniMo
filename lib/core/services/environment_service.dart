import 'dart:js' as js;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../env_config.dart';

/// Service to handle environment-specific configurations
class EnvironmentService {
  /// Initialize web-specific configurations
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
        
        // Call the JavaScript function to initialize Firebase
        if (js.context.hasProperty('initializeFirebaseConfig')) {
          js.context.callMethod('initializeFirebaseConfig', [firebaseConfig]);
        } else {
          print('Warning: initializeFirebaseConfig not found in JS context');
          // Initialize Firebase directly if the method isn't available
          js.context['firebase']?.callMethod('initializeApp', [js.JsObject.jsify(firebaseConfig)]);
        }
        
        // Check if Google Maps is already loaded through script tag
        bool mapsLoaded = js.context.hasProperty('google') && 
                          js.context['google'] != null && 
                          js.context['google'].hasProperty('maps');
        
        if (!mapsLoaded) {
          print('Google Maps not detected, attempting to load dynamically');
          // Only load Google Maps if not already loaded
          _loadGoogleMapsScript();
        } else {
          print('Google Maps already loaded via script tag');
        }
      } catch (e) {
        print('Error initializing web config: $e');
        // Continue app initialization even if web config fails
      }
    }
  }
  
  /// Dynamically loads the Google Maps script for web
  static void _loadGoogleMapsScript() {
    if (kIsWeb) {
      try {
        final script = js.context['document'].callMethod('createElement', ['script']);
        script['src'] = 'https://maps.googleapis.com/maps/api/js?key=${EnvConfig.googleMapsWebApiKey}';
        script['async'] = true;
        script['defer'] = true;
        script['id'] = 'google-maps-script';
        
        // Add an onload handler
        script['onload'] = js.allowInterop(() {
          print('Google Maps script loaded dynamically');
        });
        
        // Add an error handler
        script['onerror'] = js.allowInterop((error) {
          print('Error loading Google Maps script: $error');
        });
        
        js.context['document']['head'].callMethod('appendChild', [script]);
      } catch (e) {
        print('Error loading Google Maps script: $e');
        // Continue without Google Maps if loading fails
      }
    }
  }
  
  /// Initialize Android-specific configurations
  static Future<void> initializeAndroidConfig() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // You could add Android-specific initialization here
      // For example, you might need to set API keys for certain native plugins
    }
  }
  
  /// Initialize all environment configurations
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