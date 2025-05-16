import 'package:flutter/foundation.dart';

/// Helper for map-related functionality in mobile environments.
///
/// Provides platform-specific implementations that work correctly on mobile
/// platforms without requiring dart:js.
class MapPickerHelper {
  /// Checks if Google Maps functionality is available.
  ///
  /// On mobile platforms, this always returns true as Maps availability
  /// is determined by the native plugin.
  static bool isGoogleMapsAvailable() {
    return true;
  }
} 