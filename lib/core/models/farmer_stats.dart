import 'activity_item.dart';

class FarmerStats {
  final String farmerName;
  final int totalActiveListings;
  final double totalListingsValue;
  final int pendingMatchSuggestions;
  final int pendingConfirmationOrdersCount;
  final int activeInProgressOrdersCount; // New field for active, non-completed, non-pending-confirmation orders

  FarmerStats({
    required this.farmerName,
    required this.totalActiveListings,
    required this.totalListingsValue,
    required this.pendingMatchSuggestions,
    required this.pendingConfirmationOrdersCount,
    required this.activeInProgressOrdersCount, // New field
  });
}