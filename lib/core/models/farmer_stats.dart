/// Represents statistical data for a farmer's marketplace activity.
///
/// Contains aggregated metrics about a farmer's listings, orders, and 
/// other business activities to provide a snapshot of their current status.
class FarmerStats {
  /// Display name of the farmer.
  final String farmerName;
  
  /// Number of produce listings currently active in the marketplace.
  final int totalActiveListings; // Count of active produce listings
  
  /// Total value (quantity * price) of all active produce listings.
  final double totalActiveListingsValue; // New: Sum of (quantity * pricePerUnit) for active listings
  
  /// Total value of all completed orders over time.
  final double totalListingsValue; // This will now represent total value from COMPLETED orders
  
  /// Number of match suggestions waiting for farmer review.
  final int pendingMatchSuggestions;
  
  /// Number of orders waiting for confirmation from the farmer.
  final int pendingConfirmationOrdersCount;
  
  /// Number of confirmed orders that are currently in progress.
  final int activeInProgressOrdersCount;
  
  /// Number of delivered orders waiting for final completion.
  final int deliveredOrdersToCompleteCount;

  /// Creates a new [FarmerStats] instance with the specified metrics.
  ///
  /// All parameters are required to provide a complete statistical view.
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