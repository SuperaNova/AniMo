import 'package:cloud_firestore/cloud_firestore.dart';
import './location_data.dart'; // For DeliveryLocation

/// Status of a buyer's request for produce.
///
/// Tracks the current state of a buyer's request through its lifecycle.
enum BuyerRequestStatus {
  /// Request is active and waiting for farmers to match with it.
  pending_match,
  
  /// Some orders have been created against this request, but quantity is not fully met.
  partially_fulfilled,
  
  /// All requested quantity has been fulfilled by orders.
  fully_fulfilled,
  
  /// Request expired without being matched to any farmers.
  expired_unmatched,
  
  /// Request was cancelled by the buyer before fulfillment.
  cancelled_by_buyer,
}

/// Converts a [BuyerRequestStatus] to its string representation.
///
/// Returns the name of the status enum value.
String buyerRequestStatusToString(BuyerRequestStatus status) {
  return status.name;
}

/// Converts a string to a [BuyerRequestStatus].
///
/// The [statusString] should match the name of a status enum value.
/// Returns the status value matching the string, or [BuyerRequestStatus.pending_match]
/// if no match is found.
BuyerRequestStatus buyerRequestStatusFromString(String? statusString) {
  return BuyerRequestStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => BuyerRequestStatus.pending_match,
      );
}

/// Represents a buyer's request for specific produce.
///
/// Contains all information about a request including the produce needed,
/// quantity, delivery details, and status. This model is used to match
/// buyers with farmers who can fulfill their needs.
class BuyerRequest {
  /// Unique identifier for the request.
  final String? id;
  
  /// ID of the buyer who created the request.
  final String buyerId;
  
  /// Name of the buyer (denormalized for easier display).
  final String? buyerName;

  /// Date and time when the request was created.
  final Timestamp requestDateTime;
  
  /// Name of the specific produce being requested (e.g., "Tomatoes").
  final String? produceNeededName;
  
  /// Category of the produce being requested (e.g., "Vegetable").
  final String produceNeededCategory;
  
  /// Quantity of produce needed.
  final double quantityNeeded;
  
  /// Unit of measurement for the quantity (e.g., "kg", "piece").
  final String quantityUnit;

  /// Location where the produce should be delivered.
  final LocationData deliveryLocation;
  
  /// Deadline by which the delivery should be completed.
  final Timestamp deliveryDeadline;

  /// Minimum price per unit the buyer is willing to pay.
  final double? priceRangeMinPerUnit;
  
  /// Maximum price per unit the buyer is willing to pay.
  final double? priceRangeMaxPerUnit;
  
  /// Currency for the price (e.g., "PHP").
  final String? currency;

  /// Additional notes or requirements from the buyer to the farmer.
  final String? notesForFarmer;
  
  /// Current status of the request.
  final BuyerRequestStatus status;
  
  /// Whether the buyer wants AI to proactively find matches.
  final bool isAiMatchPreferred;

  /// List of order IDs that are fulfilling this request.
  final List<String>? fulfilledByOrderIds;
  
  /// Total quantity that has been fulfilled by orders.
  final double totalQuantityFulfilled;

  /// Date and time when the request was last updated.
  final Timestamp lastUpdated;

  /// Creates a new [BuyerRequest].
  ///
  /// The [buyerId], [requestDateTime], [produceNeededCategory], [quantityNeeded],
  /// [quantityUnit], [deliveryLocation], [deliveryDeadline], [status], and [lastUpdated]
  /// parameters are required.
  BuyerRequest({
    this.id,
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
    this.isAiMatchPreferred = true,
    this.fulfilledByOrderIds,
    this.totalQuantityFulfilled = 0.0,
    required this.lastUpdated,
  });

  /// Creates a [BuyerRequest] from a Firestore document snapshot.
  ///
  /// Converts Firestore document data into a BuyerRequest instance.
  /// The [doc] parameter contains the document snapshot.
  ///
  /// Returns a [BuyerRequest] instance populated with data from Firestore.
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

  /// Converts this request to a Firestore document.
  ///
  /// Creates a map of fields suitable for storing in Firestore.
  /// Only includes non-null fields to avoid storing unnecessary null values.
  ///
  /// Returns a Map containing the request data ready for Firestore.
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

  /// Creates a copy of this request with the specified fields replaced.
  ///
  /// Returns a new [BuyerRequest] instance with updated fields while preserving
  /// the values of fields that are not specified.
  BuyerRequest copyWith({
    String? id,
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