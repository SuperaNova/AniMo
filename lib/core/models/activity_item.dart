import 'package:flutter/cupertino.dart';

class ActivityItem {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailingText; // e.g., amount or status

  ActivityItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingText,
  });
}