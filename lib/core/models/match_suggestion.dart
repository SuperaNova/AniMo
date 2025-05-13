import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchSuggestionStatus {
  pending_farmer_action, // Waiting for farmer to accept/reject
  pending_buyer_action,  // Waiting for buyer to accept/reject (can also be initial if farmer already implicitly agreed by listing)
  farmer_accepted,       // Farmer accepted, waiting for buyer
  buyer_accepted,        // Buyer accepted, waiting for farmer
  // If both accept, the status might directly go to 'order_created' or an intermediate like 'awaiting_order_creation'
  order_created,         // An order was successfully created from this suggestion
  farmer_rejected,
  buyer_rejected,
  expired,               // No action taken within a certain time
  error,                 // Some error occurred processing this suggestion
}

String matchSuggestionStatusToString(MatchSuggestionStatus status) {
  return status.name;
}

MatchSuggestionStatus matchSuggestionStatusFromString(String? statusString) {
  return MatchSuggestionStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => MatchSuggestionStatus.pending_farmer_action, // Or a more generic pending
      );
}


class MatchSuggestion {
  final String id; // Document ID
  final Timestamp creationTimestamp;

  final String listingId;
  final String farmerId;
  final String? produceName; // Denormalized from ProduceListing
  final double? listingQuantityAvailable; // Denormalized at time of suggestion
  final String? listingQuantityUnit; // Denormalized

  final String? buyerRequestId; // Optional, if match originated from a BuyerRequest
  final String buyerId; // The buyer this suggestion is for
  final double? quantityRequestedByBuyer; // From BuyerRequest, if applicable
  final String? quantityUnitRequestedByBuyer; // From BuyerRequest

  final double? aiMatchScore;
  final String? aiMatchRationale;

  final double suggestedOrderQuantity; // The quantity AI suggests for THIS transaction
  final String suggestedOrderUnit;

  final MatchSuggestionStatus status;
  final Timestamp? farmerAcceptanceTimestamp;
  final Timestamp? buyerAcceptanceTimestamp;
  final Timestamp? farmerRejectionTimestamp;
  final String? farmerRejectionReason;
  final Timestamp? buyerRejectionTimestamp;
  final String? buyerRejectionReason;
  
  final String? relatedOrderId; // If an order is created
  final Timestamp lastUpdated;

  MatchSuggestion({
    required this.id,
    required this.creationTimestamp,
    required this.listingId,
    required this.farmerId,
    this.produceName,
    this.listingQuantityAvailable,
    this.listingQuantityUnit,
    this.buyerRequestId,
    required this.buyerId,
    this.quantityRequestedByBuyer,
    this.quantityUnitRequestedByBuyer,
    this.aiMatchScore,
    this.aiMatchRationale,
    required this.suggestedOrderQuantity,
    required this.suggestedOrderUnit,
    required this.status,
    this.farmerAcceptanceTimestamp,
    this.buyerAcceptanceTimestamp,
    this.farmerRejectionTimestamp,
    this.farmerRejectionReason,
    this.buyerRejectionTimestamp,
    this.buyerRejectionReason,
    this.relatedOrderId,
    required this.lastUpdated,
  });

  factory MatchSuggestion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MatchSuggestion(
      id: doc.id,
      creationTimestamp: data['creationTimestamp'] as Timestamp? ?? Timestamp.now(),
      listingId: data['listingId'] as String,
      farmerId: data['farmerId'] as String,
      produceName: data['produceName'] as String?,
      listingQuantityAvailable: (data['listingQuantityAvailable'] as num?)?.toDouble(),
      listingQuantityUnit: data['listingQuantityUnit'] as String?,
      buyerRequestId: data['buyerRequestId'] as String?,
      buyerId: data['buyerId'] as String,
      quantityRequestedByBuyer: (data['quantityRequestedByBuyer'] as num?)?.toDouble(),
      quantityUnitRequestedByBuyer: data['quantityUnitRequestedByBuyer'] as String?,
      aiMatchScore: (data['aiMatchScore'] as num?)?.toDouble(),
      aiMatchRationale: data['aiMatchRationale'] as String?,
      suggestedOrderQuantity: (data['suggestedOrderQuantity'] as num).toDouble(),
      suggestedOrderUnit: data['suggestedOrderUnit'] as String,
      status: matchSuggestionStatusFromString(data['status'] as String?),
      farmerAcceptanceTimestamp: data['farmerAcceptanceTimestamp'] as Timestamp?,
      buyerAcceptanceTimestamp: data['buyerAcceptanceTimestamp'] as Timestamp?,
      farmerRejectionTimestamp: data['farmerRejectionTimestamp'] as Timestamp?,
      farmerRejectionReason: data['farmerRejectionReason'] as String?,
      buyerRejectionTimestamp: data['buyerRejectionTimestamp'] as Timestamp?,
      buyerRejectionReason: data['buyerRejectionReason'] as String?,
      relatedOrderId: data['relatedOrderId'] as String?,
      lastUpdated: data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creationTimestamp': creationTimestamp,
      'listingId': listingId,
      'farmerId': farmerId,
      if (produceName != null) 'produceName': produceName,
      if (listingQuantityAvailable != null) 'listingQuantityAvailable': listingQuantityAvailable,
      if (listingQuantityUnit != null) 'listingQuantityUnit': listingQuantityUnit,
      if (buyerRequestId != null) 'buyerRequestId': buyerRequestId,
      'buyerId': buyerId,
      if (quantityRequestedByBuyer != null) 'quantityRequestedByBuyer': quantityRequestedByBuyer,
      if (quantityUnitRequestedByBuyer != null) 'quantityUnitRequestedByBuyer': quantityUnitRequestedByBuyer,
      if (aiMatchScore != null) 'aiMatchScore': aiMatchScore,
      if (aiMatchRationale != null) 'aiMatchRationale': aiMatchRationale,
      'suggestedOrderQuantity': suggestedOrderQuantity,
      'suggestedOrderUnit': suggestedOrderUnit,
      'status': matchSuggestionStatusToString(status),
      if (farmerAcceptanceTimestamp != null) 'farmerAcceptanceTimestamp': farmerAcceptanceTimestamp,
      if (buyerAcceptanceTimestamp != null) 'buyerAcceptanceTimestamp': buyerAcceptanceTimestamp,
      if (farmerRejectionTimestamp != null) 'farmerRejectionTimestamp': farmerRejectionTimestamp,
      if (farmerRejectionReason != null) 'farmerRejectionReason': farmerRejectionReason,
      if (buyerRejectionTimestamp != null) 'buyerRejectionTimestamp': buyerRejectionTimestamp,
      if (buyerRejectionReason != null) 'buyerRejectionReason': buyerRejectionReason,
      if (relatedOrderId != null) 'relatedOrderId': relatedOrderId,
      'lastUpdated': lastUpdated,
    };
  }
} 