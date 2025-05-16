class FarmerStats {
  final String farmerName;
  final int totalActiveListings; // Count of active produce listings
  final double totalActiveListingsValue; // New: Sum of (quantity * pricePerUnit) for active listings
  final double totalListingsValue; // This will now represent total value from COMPLETED orders
  final int pendingMatchSuggestions;
  final int pendingConfirmationOrdersCount;
  final int activeInProgressOrdersCount;
  final int deliveredOrdersToCompleteCount;

  FarmerStats({
    required this.farmerName,
    required this.totalActiveListings,
    required this.totalActiveListingsValue, // New
    required this.totalListingsValue, // Represents completed orders value
    required this.pendingMatchSuggestions,
    required this.pendingConfirmationOrdersCount,
    required this.activeInProgressOrdersCount,
    required this.deliveredOrdersToCompleteCount,
  });
}