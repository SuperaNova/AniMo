import 'package:cloud_firestore/cloud_firestore.dart';
import './location_data.dart'; // Import the new location_data.dart
import 'package:flutter/foundation.dart'; // For debugPrint

// Helper class for GeoPoint-like structure
// class LocationData { ... MOVED TO location_data.dart ... }

import 'package:flutter/material.dart';

enum ProduceCategory {
  vegetable('Vegetable'),
  fruit('Fruit'),
  herb('Herb'),
  grain('Grain'),
  processed('Processed Farm Product'),
  other('Other');

  const ProduceCategory(this.displayName);
  final String displayName;

  Color get color {
    switch (this) {
      case ProduceCategory.vegetable:
        return Colors.green;
      case ProduceCategory.fruit:
        return Colors.red;
      case ProduceCategory.herb:
        return Colors.teal;
      case ProduceCategory.grain:
        return Colors.brown;
      case ProduceCategory.processed:
        return Colors.orange;
      case ProduceCategory.other:
        return Colors.grey;
    }
  }

  // Helper to get an icon for a produce category for ActivityItem
  IconData get icon {
    switch (this) {
      case ProduceCategory.vegetable:
        return Icons.eco_rounded;
      case ProduceCategory.fruit:
        return Icons.apple_rounded;
      case ProduceCategory.herb:
        return Icons.grass_rounded;
      case ProduceCategory.grain:
        return Icons.grain_rounded;
      case ProduceCategory.processed:
        return Icons.settings_applications_outlined;
      case ProduceCategory.other:
        return Icons.category_rounded;
    }
  }
}

enum ProduceListingStatus {
  available('Available'),
  // pending_confirmation ('Pending Confirmation'), // If a match is made but not yet an order
  committed('Committed to Order'), // Part or all quantity is committed
  sold_out('Sold Out'), // All quantity sold and delivered
  expired('Expired'),
  delisted('Delisted by Farmer');

  const ProduceListingStatus(this.displayName);
  final String displayName;
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
  final String? id;
  final String farmerId;
  final String? farmerName; // Denormalized for easier display
  final String produceName;
  final ProduceCategory produceCategory;
  final String? customProduceCategory; // If produceCategory is 'other'
  final double quantity; // Current available quantity
  final double initialQuantity; // Original quantity when listed
  final String unit; // e.g., kg, piece, bundle, sack, kaing
  final double? estimatedWeightKgPerUnit; // For non-standard units like 'sack' or 'piece'
  final double pricePerUnit;
  final String currency;
  final String? description;
  final LocationData pickupLocation;
  final List<String> photoUrls;
  final ProduceListingStatus status;
  final DateTime? harvestTimestamp; // Optional
  final DateTime? expiryTimestamp;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final double quantityCommitted; // Quantity tied up in active orders/accepted matches
  final double quantitySoldAndDelivered; // Quantity successfully sold and delivered

  ProduceListing({
    this.id,
    required this.farmerId,
    this.farmerName,
    required this.produceName,
    required this.produceCategory,
    this.customProduceCategory,
    required this.quantity,
    required this.initialQuantity,
    required this.unit,
    this.estimatedWeightKgPerUnit,
    required this.pricePerUnit,
    required this.currency,
    this.description,
    required this.pickupLocation,
    this.photoUrls = const [],
    required this.status,
    this.harvestTimestamp,
    this.expiryTimestamp,
    required this.createdAt,
    required this.lastUpdated,
    this.quantityCommitted = 0,
    this.quantitySoldAndDelivered = 0,
  });

  factory ProduceListing.fromFirestore(Map<String, dynamic> data, String id) {
    if (kDebugMode) {
      debugPrint('Parsing ProduceListing (ID: $id): $data');
    }
    try {
      return ProduceListing(
        id: id,
        farmerId: data['farmerId'] as String,
        farmerName: data['farmerName'] as String?,
        produceName: data['produceName'] as String,
        produceCategory: ProduceCategory.values.firstWhere(
          (e) => e.name == data['produceCategory'],
          orElse: () {
            if (kDebugMode) {
              debugPrint('Error parsing produceCategory for $id: Value was ${data['produceCategory']}');
            }
            return ProduceCategory.other;
          },
        ),
        customProduceCategory: data['customProduceCategory'] as String?,
        quantity: (data['quantity'] as num).toDouble(),
        initialQuantity: (data['initialQuantity'] as num).toDouble(),
        unit: data['unit'] as String,
        estimatedWeightKgPerUnit: (data['estimatedWeightKgPerUnit'] as num?)?.toDouble(),
        pricePerUnit: (data['pricePerUnit'] as num).toDouble(),
        currency: data['currency'] as String,
        description: data['description'] as String?,
        pickupLocation: LocationData.fromMap(data['pickupLocation'] as Map<String, dynamic>),
        photoUrls: List<String>.from(data['photoUrls'] as List<dynamic>? ?? []),
        status: ProduceListingStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () {
            if (kDebugMode) {
              debugPrint('Error parsing status for $id: Value was ${data['status']}');
            }
            return ProduceListingStatus.available;
          },
        ),
        harvestTimestamp: (data['harvestTimestamp'] as Timestamp?)?.toDate(),
        expiryTimestamp: (data['expiryTimestamp'] as Timestamp?)?.toDate(),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
        quantityCommitted: (data['quantityCommitted'] as num? ?? 0).toDouble(),
        quantitySoldAndDelivered: (data['quantitySoldAndDelivered'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing ProduceListing $id: $e. Data: $data');
      }
      // Rethrow or return a specific error object, or handle as per your app's error strategy
      // For now, rethrowing so it's visible in StreamBuilder's error state if not caught elsewhere.
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'farmerId': farmerId,
      if (farmerName != null) 'farmerName': farmerName,
      'produceName': produceName,
      'produceCategory': produceCategory.name,
      if (customProduceCategory != null) 'customProduceCategory': customProduceCategory,
      'quantity': quantity,
      'initialQuantity': initialQuantity,
      'unit': unit,
      if (estimatedWeightKgPerUnit != null) 'estimatedWeightKgPerUnit': estimatedWeightKgPerUnit,
      'pricePerUnit': pricePerUnit,
      'currency': currency,
      if (description != null) 'description': description,
      'pickupLocation': pickupLocation.toMap(),
      'photoUrls': photoUrls,
      'status': status.name,
      if (harvestTimestamp != null) 'harvestTimestamp': Timestamp.fromDate(harvestTimestamp!),
      if (expiryTimestamp != null) 'expiryTimestamp': Timestamp.fromDate(expiryTimestamp!),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'quantityCommitted': quantityCommitted,
      'quantitySoldAndDelivered': quantitySoldAndDelivered,
    };
  }

  ProduceListing copyWith({
    String? id,
    String? farmerId,
    String? farmerName,
    String? produceName,
    ProduceCategory? produceCategory,
    String? customProduceCategory,
    double? quantity,
    double? initialQuantity,
    String? unit,
    double? estimatedWeightKgPerUnit,
    double? pricePerUnit,
    String? currency,
    String? description,
    LocationData? pickupLocation,
    List<String>? photoUrls,
    ProduceListingStatus? status,
    DateTime? harvestTimestamp,
    DateTime? expiryTimestamp,
    DateTime? createdAt,
    DateTime? lastUpdated,
    double? quantityCommitted,
    double? quantitySoldAndDelivered,
  }) {
    return ProduceListing(
      id: id ?? this.id,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      produceName: produceName ?? this.produceName,
      produceCategory: produceCategory ?? this.produceCategory,
      customProduceCategory: customProduceCategory ?? this.customProduceCategory,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      unit: unit ?? this.unit,
      estimatedWeightKgPerUnit: estimatedWeightKgPerUnit ?? this.estimatedWeightKgPerUnit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      photoUrls: photoUrls ?? this.photoUrls,
      status: status ?? this.status,
      harvestTimestamp: harvestTimestamp ?? this.harvestTimestamp,
      expiryTimestamp: expiryTimestamp ?? this.expiryTimestamp,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      quantityCommitted: quantityCommitted ?? this.quantityCommitted,
      quantitySoldAndDelivered: quantitySoldAndDelivered ?? this.quantitySoldAndDelivered,
    );
  }
} 