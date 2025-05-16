import 'package:cloud_firestore/cloud_firestore.dart';
// For ProduceListing reference
// For BuyerRequest reference
// import './order.dart'; // Potentially for Order reference

enum MatchStatus {
  pending_farmer_approval('Pending Farmer Approval'),
  pending_buyer_approval('Pending Buyer Approval'),
  // pending_both_approval('Pending Both Approvals'), // if parallel approval is allowed
  accepted_by_farmer('Accepted by Farmer'),
  accepted_by_buyer('Accepted by Buyer'),
  confirmed('Confirmed by Both'), // Ready to become an order
  rejected_by_farmer('Rejected by Farmer'),
  rejected_by_buyer('Rejected by Buyer'),
  expired('Expired'), // Suggestion timed out
  cancelled('Cancelled'), // e.g. if listing becomes unavailable
  order_created('Order Created'),
  ai_suggestion_for_buyer('AI Suggestion'); // Added for AI-generated suggestions

  const MatchStatus(this.displayName);
  final String displayName;
}

class MatchSuggestion {
  final String? id;
  final String produceListingId;
  // final ProduceListing? produceListing; // Optional: denormalized full listing, or fetch separately
  final String farmerId; // Denormalized from ProduceListing for easier querying/rules

  final String? buyerRequestId; // Null if it's a direct match from buyer interest not a formal request
  // final BuyerRequest? buyerRequest; // Optional: denormalized full request
  final String buyerId; // Who showed interest or made the request

  // ADDED: Denormalized fields for easier display
  final String produceName;
  final String? farmerName;
  final String? buyerName;

  final double suggestedQuantity;
  final String unit; // Should match produceListing.unit
  final double? suggestedPricePerUnit; // Can be from listing, or negotiated, or from buyer request range
  final String? currency; // Should match

  // AI/System generated fields
  final double aiMatchScore; // 0.0 to 1.0
  final String aiMatchRationale; // Brief explanation
  final String? systemNotes; // e.g., "Prioritized due to nearing expiry"

  final MatchStatus status;
  final String? farmerRejectionReason;
  final String? buyerRejectionReason;

  final DateTime createdAt;
  final DateTime lastUpdated;
  final DateTime? expiresAt; // When this suggestion is no longer valid

  final String? createdOrderId; // ID of the Order created from this match

  MatchSuggestion({
    this.id,
    required this.produceListingId,
    required this.farmerId,
    this.buyerRequestId,
    required this.buyerId,
    // ADDED: New fields in constructor
    required this.produceName,
    this.farmerName,
    this.buyerName,
    required this.suggestedQuantity,
    required this.unit,
    this.suggestedPricePerUnit,
    this.currency,
    required this.aiMatchScore,
    required this.aiMatchRationale,
    this.systemNotes,
    required this.status,
    this.farmerRejectionReason,
    this.buyerRejectionReason,
    required this.createdAt,
    required this.lastUpdated,
    this.expiresAt,
    this.createdOrderId,
    // this.produceListing, // Removed to avoid circular dependency if full obj is embedded
    // this.buyerRequest,
  });

  factory MatchSuggestion.fromFirestore(Map<String, dynamic> data, String id) {
    return MatchSuggestion(
      id: id,
      produceListingId: data['produceListingId'] as String,
      farmerId: data['farmerId'] as String,
      buyerRequestId: data['buyerRequestId'] as String?,
      buyerId: data['buyerId'] as String,
      // ADDED: New fields in fromFirestore
      produceName: data['produceName'] as String? ?? 'Unknown Produce', // Provide a fallback
      farmerName: data['farmerName'] as String?,
      buyerName: data['buyerName'] as String?,
      suggestedQuantity: (data['suggestedQuantity'] as num).toDouble(),
      unit: data['unit'] as String,
      suggestedPricePerUnit: (data['suggestedPricePerUnit'] as num?)?.toDouble(),
      currency: data['currency'] as String?,
      aiMatchScore: (data['aiMatchScore'] as num).toDouble(),
      aiMatchRationale: data['aiMatchRationale'] as String,
      systemNotes: data['systemNotes'] as String?,
      status: MatchStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => MatchStatus.pending_farmer_approval, // Sensible default
      ),
      farmerRejectionReason: data['farmerRejectionReason'] as String?,
      buyerRejectionReason: data['buyerRejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      createdOrderId: data['createdOrderId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'produceListingId': produceListingId,
      'farmerId': farmerId,
      if (buyerRequestId != null) 'buyerRequestId': buyerRequestId,
      'buyerId': buyerId,
      // ADDED: New fields in toFirestore
      'produceName': produceName,
      if (farmerName != null) 'farmerName': farmerName,
      if (buyerName != null) 'buyerName': buyerName,
      'suggestedQuantity': suggestedQuantity,
      'unit': unit,
      if (suggestedPricePerUnit != null) 'suggestedPricePerUnit': suggestedPricePerUnit,
      if (currency != null) 'currency': currency,
      'aiMatchScore': aiMatchScore,
      'aiMatchRationale': aiMatchRationale,
      if (systemNotes != null) 'systemNotes': systemNotes,
      'status': status.name,
      if (farmerRejectionReason != null) 'farmerRejectionReason': farmerRejectionReason,
      if (buyerRejectionReason != null) 'buyerRejectionReason': buyerRejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (createdOrderId != null) 'createdOrderId': createdOrderId,
    };
  }

  MatchSuggestion copyWith({
    String? id,
    String? produceListingId,
    String? farmerId,
    String? buyerRequestId,
    String? buyerId,
    // ADDED: New fields in copyWith
    String? produceName,
    String? farmerName,
    String? buyerName,
    double? suggestedQuantity,
    String? unit,
    double? suggestedPricePerUnit,
    String? currency,
    double? aiMatchScore,
    String? aiMatchRationale,
    String? systemNotes,
    MatchStatus? status,
    String? farmerRejectionReason,
    String? buyerRejectionReason,
    DateTime? createdAt,
    DateTime? lastUpdated,
    DateTime? expiresAt,
    String? createdOrderId,
  }) {
    return MatchSuggestion(
      id: id ?? this.id,
      produceListingId: produceListingId ?? this.produceListingId,
      farmerId: farmerId ?? this.farmerId,
      buyerRequestId: buyerRequestId ?? this.buyerRequestId,
      buyerId: buyerId ?? this.buyerId,
      // ADDED: New fields in copyWith
      produceName: produceName ?? this.produceName,
      farmerName: farmerName ?? this.farmerName,
      buyerName: buyerName ?? this.buyerName,
      suggestedQuantity: suggestedQuantity ?? this.suggestedQuantity,
      unit: unit ?? this.unit,
      suggestedPricePerUnit: suggestedPricePerUnit ?? this.suggestedPricePerUnit,
      currency: currency ?? this.currency,
      aiMatchScore: aiMatchScore ?? this.aiMatchScore,
      aiMatchRationale: aiMatchRationale ?? this.aiMatchRationale,
      systemNotes: systemNotes ?? this.systemNotes,
      status: status ?? this.status,
      farmerRejectionReason: farmerRejectionReason ?? this.farmerRejectionReason,
      buyerRejectionReason: buyerRejectionReason ?? this.buyerRejectionReason,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      expiresAt: expiresAt ?? this.expiresAt,
      createdOrderId: createdOrderId ?? this.createdOrderId,
    );
  }
} 