import 'package:cloud_firestore/cloud_firestore.dart';
import './location_data.dart'; // For DeliveryLocation

enum BuyerRequestStatus {
  pending_match,
  partially_fulfilled, // Some orders created against this request
  fully_fulfilled,     // All quantityNeeded has been met by orders
  expired_unmatched,
  cancelled_by_buyer,
}

String buyerRequestStatusToString(BuyerRequestStatus status) {
  return status.name;
}

BuyerRequestStatus buyerRequestStatusFromString(String? statusString) {
  return BuyerRequestStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => BuyerRequestStatus.pending_match,
      );
}

class BuyerRequest {
  final String? id; // Document ID - Made nullable
  final String buyerId;
  final String? buyerName; // Denormalized

  final Timestamp requestDateTime;
  final String? produceNeededName; // e.g., "Tomatoes", "Any leafy greens"
  final String produceNeededCategory; // e.g., "Vegetable", "Fruit"
  
  final double quantityNeeded;
  final String quantityUnit; // e.g., "kg", "piece"

  final LocationData deliveryLocation;
  final Timestamp deliveryDeadline;

  final double? priceRangeMinPerUnit;
  final double? priceRangeMaxPerUnit;
  final String? currency; // e.g., "PHP"

  final String? notesForFarmer;
  final BuyerRequestStatus status;
  final bool isAiMatchPreferred; // If buyer wants AI to proactively find matches

  final List<String>? fulfilledByOrderIds; // List of Order IDs fulfilling this
  final double totalQuantityFulfilled;  // Sum of quantities from fulfilledByOrderIds

  final Timestamp lastUpdated;

  BuyerRequest({
    this.id, // No longer required
    required this.buyerId,
    this.buyerName,
    required this.requestDateTime,
    this.produceNeededName,
    required this.produceNeededCategory,
    required this.quantityNeeded,
    required this.quantityUnit,
    required this.deliveryLocation,
    required this.deliveryDeadline,
    this.priceRangeMinPerUnit,
    this.priceRangeMaxPerUnit,
    this.currency,
    this.notesForFarmer,
    required this.status,
    this.isAiMatchPreferred = true, // Default to true
    this.fulfilledByOrderIds,
    this.totalQuantityFulfilled = 0.0,
    required this.lastUpdated,
  });

  factory BuyerRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return BuyerRequest(
      id: doc.id,
      buyerId: data['buyerId'] as String,
      buyerName: data['buyerName'] as String?,
      requestDateTime: data['requestDateTime'] as Timestamp? ?? Timestamp.now(),
      produceNeededName: data['produceNeededName'] as String?,
      produceNeededCategory: data['produceNeededCategory'] as String,
      quantityNeeded: (data['quantityNeeded'] as num).toDouble(),
      quantityUnit: data['quantityUnit'] as String,
      deliveryLocation: LocationData.fromMap(data['deliveryLocation'] as Map<String, dynamic>?),
      deliveryDeadline: data['deliveryDeadline'] as Timestamp,
      priceRangeMinPerUnit: (data['priceRangeMinPerUnit'] as num?)?.toDouble(),
      priceRangeMaxPerUnit: (data['priceRangeMaxPerUnit'] as num?)?.toDouble(),
      currency: data['currency'] as String?,
      notesForFarmer: data['notesForFarmer'] as String?,
      status: buyerRequestStatusFromString(data['status'] as String?),
      isAiMatchPreferred: data['isAiMatchPreferred'] as bool? ?? true,
      fulfilledByOrderIds: (data['fulfilledByOrderIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      totalQuantityFulfilled: (data['totalQuantityFulfilled'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'buyerId': buyerId,
      if (buyerName != null) 'buyerName': buyerName,
      'requestDateTime': requestDateTime,
      if (produceNeededName != null) 'produceNeededName': produceNeededName,
      'produceNeededCategory': produceNeededCategory,
      'quantityNeeded': quantityNeeded,
      'quantityUnit': quantityUnit,
      'deliveryLocation': deliveryLocation.toMap(),
      'deliveryDeadline': deliveryDeadline,
      if (priceRangeMinPerUnit != null) 'priceRangeMinPerUnit': priceRangeMinPerUnit,
      if (priceRangeMaxPerUnit != null) 'priceRangeMaxPerUnit': priceRangeMaxPerUnit,
      if (currency != null) 'currency': currency,
      if (notesForFarmer != null) 'notesForFarmer': notesForFarmer,
      'status': buyerRequestStatusToString(status),
      'isAiMatchPreferred': isAiMatchPreferred,
      if (fulfilledByOrderIds != null) 'fulfilledByOrderIds': fulfilledByOrderIds,
      'totalQuantityFulfilled': totalQuantityFulfilled,
      'lastUpdated': lastUpdated,
    };
  }

  BuyerRequest copyWith({
    String? id, // Stays nullable
    String? buyerId,
    String? buyerName,
    Timestamp? requestDateTime,
    String? produceNeededName,
    String? produceNeededCategory,
    double? quantityNeeded,
    String? quantityUnit,
    LocationData? deliveryLocation,
    Timestamp? deliveryDeadline,
    double? priceRangeMinPerUnit,
    double? priceRangeMaxPerUnit,
    String? currency,
    String? notesForFarmer,
    BuyerRequestStatus? status,
    bool? isAiMatchPreferred,
    List<String>? fulfilledByOrderIds,
    double? totalQuantityFulfilled,
    Timestamp? lastUpdated,
  }) {
    return BuyerRequest(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      requestDateTime: requestDateTime ?? this.requestDateTime,
      produceNeededName: produceNeededName ?? this.produceNeededName,
      produceNeededCategory: produceNeededCategory ?? this.produceNeededCategory,
      quantityNeeded: quantityNeeded ?? this.quantityNeeded,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      deliveryDeadline: deliveryDeadline ?? this.deliveryDeadline,
      priceRangeMinPerUnit: priceRangeMinPerUnit ?? this.priceRangeMinPerUnit,
      priceRangeMaxPerUnit: priceRangeMaxPerUnit ?? this.priceRangeMaxPerUnit,
      currency: currency ?? this.currency,
      notesForFarmer: notesForFarmer ?? this.notesForFarmer,
      status: status ?? this.status,
      isAiMatchPreferred: isAiMatchPreferred ?? this.isAiMatchPreferred,
      fulfilledByOrderIds: fulfilledByOrderIds ?? this.fulfilledByOrderIds,
      totalQuantityFulfilled: totalQuantityFulfilled ?? this.totalQuantityFulfilled,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
} 