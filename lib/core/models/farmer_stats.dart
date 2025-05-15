import 'activity_item.dart';

class FarmerStats {
  final int totalActiveListings;
  final double totalListingsValue;
  final int pendingMatchSuggestions;
  final List<ActivityItem> recentActivity;
  final String farmerName;

  FarmerStats({
    required this.totalActiveListings,
    required this.totalListingsValue,
    required this.pendingMatchSuggestions,
    required this.recentActivity,
    required this.farmerName,
  });
}