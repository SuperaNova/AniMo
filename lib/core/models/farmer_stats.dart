class FarmerStats {
  final String farmerName;
  final int totalActiveListings;
  final double totalListingsValue;
  final int pendingMatchSuggestions;
  final int pendingConfirmationOrdersCount;
  final int activeInProgressOrdersCount;
  final int deliveredOrdersToCompleteCount;

  FarmerStats({
    required this.farmerName,
    required this.totalActiveListings,
    required this.totalListingsValue,
    required this.pendingMatchSuggestions,
    required this.pendingConfirmationOrdersCount,
    required this.activeInProgressOrdersCount,
    required this.deliveredOrdersToCompleteCount,
  });
}