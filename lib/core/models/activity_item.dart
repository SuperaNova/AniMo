import 'package:flutter/cupertino.dart';

/// Represents an item in an activity feed or history list.
///
/// Contains display information for a list item including icon, colors,
/// and text content to show user activity or history items in a consistent format.
class ActivityItem {
  /// Icon to display for this activity.
  final IconData icon;
  
  /// Background color for the icon container.
  final Color iconBgColor;
  
  /// Color for the icon itself.
  final Color iconColor;
  
  /// Main title text for the activity item.
  final String title;
  
  /// Subtitle or description text providing additional details.
  final String subtitle;
  
  /// Text to display in the trailing position (e.g., amount, date, or status).
  final String trailingText; // e.g., amount or status

  /// Creates a new [ActivityItem] with the specified display properties.
  ///
  /// All parameters are required to ensure consistent display of activity items.
  ActivityItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingText,
  });
}