import 'package:cloud_firestore/cloud_firestore.dart';
import './location_data.dart'; // Import the new location_data.dart

// Helper class for GeoPoint-like structure
// class LocationData { ... MOVED TO location_data.dart ... }

enum ProduceListingStatus {
  available,
  unavailable, // e.g. fully ordered or taken down by farmer
  expired,
  pending_approval, // if moderation is added
  deleted // soft delete
}

String produceListingStatusToString(ProduceListingStatus status) {
  return status.name;
}

ProduceListingStatus produceListingStatusFromString(String? statusString) {
  return ProduceListingStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => ProduceListingStatus.available, // Default or error
      );
}


class ProduceListing {
  final String id; // Document ID from Firestore
  final String farmerId;
  final String? farmerName; // Denormalized
  final String produceName;
  final String produceCategory;
  final String? customProduceCategory;
  
  final double initialQuantity;
  final String quantityUnit;
  final double? estimatedWeightKg;
  final int? estimatedPieceCount;

  final double? pricePerUnit;
  final String? currency; // e.g., "PHP"

  final Timestamp harvestDateTime;
  final int shelfLifeDays;
  final Timestamp expiryTimestamp; // Calculated: harvestDateTime + shelfLifeDays
  
  final Timestamp listingDateTime;
  final LocationData pickupLocation;
  final List<String>? photoUrls; // URLs to images in Firebase Storage
  
  final ProduceListingStatus status;
  final String? notes;
  final Timestamp lastUpdated;

  // Fields for tracking quantity based on orders
  final double quantityCommitted; // Committed in active orders
  final double quantitySoldAndDelivered; // Sold and delivered from this listing

  ProduceListing({
    required this.id,
    required this.farmerId,
    this.farmerName,
    required this.produceName,
    required this.produceCategory,
    this.customProduceCategory,
    required this.initialQuantity,
    required this.quantityUnit,
    this.estimatedWeightKg,
    this.estimatedPieceCount,
    this.pricePerUnit,
    this.currency,
    required this.harvestDateTime,
    required this.shelfLifeDays,
    required this.expiryTimestamp,
    required this.listingDateTime,
    required this.pickupLocation,
    this.photoUrls,
    required this.status,
    this.notes,
    required this.lastUpdated,
    this.quantityCommitted = 0.0,
    this.quantitySoldAndDelivered = 0.0,
  });

  // Calculated property for current available quantity
  double get currentAvailableQuantity {
    double available = initialQuantity - quantityCommitted - quantitySoldAndDelivered;
    return available < 0 ? 0 : available;
  }

  factory ProduceListing.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProduceListing(
      id: doc.id,
      farmerId: data['farmerId'] as String,
      farmerName: data['farmerName'] as String?,
      produceName: data['produceName'] as String,
      produceCategory: data['produceCategory'] as String,
      customProduceCategory: data['customProduceCategory'] as String?,
      initialQuantity: (data['initialQuantity'] as num).toDouble(),
      quantityUnit: data['quantityUnit'] as String,
      estimatedWeightKg: (data['estimatedWeightKg'] as num?)?.toDouble(),
      estimatedPieceCount: data['estimatedPieceCount'] as int?,
      pricePerUnit: (data['pricePerUnit'] as num?)?.toDouble(),
      currency: data['currency'] as String?,
      harvestDateTime: data['harvestDateTime'] as Timestamp,
      shelfLifeDays: data['shelfLifeDays'] as int,
      expiryTimestamp: data['expiryTimestamp'] as Timestamp,
      listingDateTime: data['listingDateTime'] as Timestamp? ?? Timestamp.now(),
      pickupLocation: LocationData.fromMap(data['pickupLocation'] as Map<String, dynamic>?),
      photoUrls: (data['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList(),
      status: produceListingStatusFromString(data['status'] as String?),
      notes: data['notes'] as String?,
      lastUpdated: data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
      quantityCommitted: (data['quantityCommitted'] as num?)?.toDouble() ?? 0.0,
      quantitySoldAndDelivered: (data['quantitySoldAndDelivered'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'farmerId': farmerId,
      if (farmerName != null) 'farmerName': farmerName,
      'produceName': produceName,
      'produceCategory': produceCategory,
      if (customProduceCategory != null) 'customProduceCategory': customProduceCategory,
      'initialQuantity': initialQuantity,
      'quantityUnit': quantityUnit,
      if (estimatedWeightKg != null) 'estimatedWeightKg': estimatedWeightKg,
      if (estimatedPieceCount != null) 'estimatedPieceCount': estimatedPieceCount,
      if (pricePerUnit != null) 'pricePerUnit': pricePerUnit,
      if (currency != null) 'currency': currency,
      'harvestDateTime': harvestDateTime,
      'shelfLifeDays': shelfLifeDays,
      'expiryTimestamp': expiryTimestamp,
      'listingDateTime': listingDateTime,
      'pickupLocation': pickupLocation.toMap(),
      if (photoUrls != null) 'photoUrls': photoUrls,
      'status': produceListingStatusToString(status),
      if (notes != null) 'notes': notes,
      'lastUpdated': lastUpdated,
      'quantityCommitted': quantityCommitted,
      'quantitySoldAndDelivered': quantitySoldAndDelivered,
    };
  }
} 