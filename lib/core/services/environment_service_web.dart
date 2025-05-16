// Web-specific implementation
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Platform-specific implementation for web environment services.
///
/// Provides web-specific implementations of environment services
/// using dart:js for browser interactions.
class EnvironmentServicePlatform {
  /// Initializes Firebase in the web context.
  ///
  /// Takes a [config] map containing Firebase configuration parameters
  /// and initializes Firebase using JavaScript interop.
  static void initializeFirebase(Map<String, dynamic> config) {
    if (kIsWeb) {
      try {
        if (js.context.hasProperty('initializeFirebaseConfig')) {
          js.context.callMethod('initializeFirebaseConfig', [config]);
        } else {
          print('Warning: initializeFirebaseConfig not found in JS context');
          // Initialize Firebase directly if the method isn't available
          js.context['firebase']?.callMethod('initializeApp', [js.JsObject.jsify(config)]);
        }
      } catch (e) {
        print('Error initializing Firebase: $e');
      }
    }
  }

  /// Loads Google Maps JavaScript API in the web context.
  ///
  /// Takes an [apiKey] string and dynamically loads the Google Maps
  /// script if not already loaded.
  static void loadGoogleMaps(String apiKey) {
    if (kIsWeb) {
      try {
        // Check if Google Maps is already loaded through script tag
        bool mapsLoaded = js.context.hasProperty('google') &&
                          js.context['google'] != null &&
                          js.context['google'].hasProperty('maps');
        
        if (!mapsLoaded) {
          print('Google Maps not detected, attempting to load dynamically');
          // Only load Google Maps if not already loaded
          final script = js.context['document'].callMethod('createElement', ['script']);
          script['src'] = 'https://maps.googleapis.com/maps/api/js?key=$apiKey';
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
        } else {
          print('Google Maps already loaded via script tag');
        }
      } catch (e) {
        print('Error loading Google Maps: $e');
      }
    }
  }

  /// Checks if Google Maps is loaded in the browser.
  ///
  /// Returns true if Google Maps JavaScript API is available in the
  /// current browser context.
  static bool isGoogleMapsLoaded() {
    if (kIsWeb) {
      try {
        return js.context.hasProperty('google') &&
               js.context['google'] != null &&
               js.context['google'].hasProperty('maps');
      } catch (e) {
        print('Error checking Google Maps: $e');
      }
    }
    return false;
  }
} 