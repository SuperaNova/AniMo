// Web-specific implementation for map services
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Map service providing web-specific map functionality.
///
/// Handles checks for Google Maps API availability in web environments.
class MapService {
  /// Checks if Google Maps API is available in the browser.
  ///
  /// Returns true if Google Maps JavaScript API is properly loaded
  /// in the current browser context, false otherwise.
  static bool isGoogleMapsAvailable() {
    if (kIsWeb) {
      try {
        return js.context.hasProperty('google') &&
               js.context['google'] != null &&
               js.context['google'].hasProperty('maps');
      } catch (e) {
        print('Error checking Google Maps availability: $e');
        return false;
      }
    }
    return false;
  }
} 