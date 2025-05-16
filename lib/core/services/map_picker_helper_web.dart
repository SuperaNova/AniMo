import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Helper for map-related functionality in web environments.
///
/// Provides platform-specific implementations for checking Google Maps
/// availability and other web-specific map functionality.
class MapPickerHelper {
  /// Checks if the Google Maps JavaScript API is available in the browser.
  ///
  /// Returns true if Google Maps is loaded in the JavaScript context and
  /// has the required properties, false otherwise.
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