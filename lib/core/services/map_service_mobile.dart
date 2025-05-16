// Mobile-specific implementation for map services
import 'package:flutter/foundation.dart';

/// Map service providing mobile-specific map functionality.
///
/// Provides a compatible API for checking Maps availability on mobile platforms.
class MapService {
  /// Checks if Google Maps is available on the device.
  ///
  /// On mobile platforms, this always returns true as Maps availability
  /// is determined by the native SDK integration.
  static bool isGoogleMapsAvailable() {
    return true;
  }
} 