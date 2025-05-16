import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import './location_data.dart'; // Import the new location_data.dart
import 'package:flutter/foundation.dart'; // For debugPrint

// Helper class for GeoPoint-like structure
// class LocationData { ... MOVED TO location_data.dart ... }

import 'package:flutter/material.dart';

/// Categories of produce that can be listed in the application.
///
/// Used to organize and filter produce listings based on their type.
/// Each category has a display name and associated styling.
enum ProduceCategory {
  /// Fresh vegetables from farms.
  vegetable('Vegetable'),
  
  /// Fresh fruits from farms.
  fruit('Fruit'),
  
  /// Herbs and spices.
  herb('Herb'),
  
  /// Grain crops like rice, corn, wheat, etc.
  grain('Grain'),
  
  /// Products that have undergone processing, like dried fruits.
  processed('Processed Farm Product'),
  
  /// Any produce that doesn't fit into the other categories.
  other('Other');

  /// Creates a produce category with a display name.
  const ProduceCategory(this.displayName);
  
  /// Human-readable name for this category.
  final String displayName;

  /// Returns a color associated with this category for UI styling.
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

  /// Returns an icon representing this category.
  ///
  /// Used for visual representation in list items and activity feeds.
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

/// Status of a produce listing in the marketplace.
///
/// Tracks the lifecycle state of a listing from creation to completion.
enum ProduceListingStatus {
  /// Listing is active and produce is available for purchase.
  available('Available'),
  
  /// Part or all of the quantity is committed to pending orders.
  committed('Committed to Order'),
  
  /// All quantity has been sold and delivered.
  sold_out('Sold Out'),
  
  /// Listing has expired (based on expiry date).
  expired('Expired'),
  
  /// Listing has been manually removed by the farmer.
  delisted('Delisted by Farmer');

  /// Creates a listing status with a display name.
  const ProduceListingStatus(this.displayName);
  
  /// Human-readable name for this status.
  final String displayName;
}

/// Converts a [ProduceListingStatus] to its string representation.
///
/// Returns the name of the status enum value.
String produceListingStatusToString(ProduceListingStatus status) {
  return status.name;
}

/// Converts a string to a [ProduceListingStatus].
///
/// The [statusString] should match the name of a status enum value.
/// Returns the status value matching the string, or [ProduceListingStatus.available]
/// if no match is found.
ProduceListingStatus produceListingStatusFromString(String? statusString) {
  return ProduceListingStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => ProduceListingStatus.available, // Default or error
      );
}

/// Represents a produce listing in the marketplace.
///
/// Contains all information about a specific produce item being sold by a farmer,
/// including details about the produce, pricing, quantity, location, and current status.
class ProduceListing {
  /// Unique identifier for the listing.
  final String? id;
  
  /// ID of the farmer who created the listing.
  final String farmerId;
  
  /// Name of the farmer (denormalized for easier display).
  final String? farmerName;
  
  /// Name of the produce item being sold.
  final String produceName;
  
  /// Category of the produce.
  final ProduceCategory produceCategory;
  
  /// Custom category name if [produceCategory] is [ProduceCategory.other].
  final String? customProduceCategory;
  
  /// Current available quantity of the produce.
  final double quantity;
  
  /// Original quantity when the produce was first listed.
  final double initialQuantity;
  
  /// Unit of measurement (e.g., kg, piece, bundle, sack, kaing).
  final String unit;
  
  /// Estimated weight in kilograms per unit for non-standard units.
  final double? estimatedWeightKgPerUnit;
  
  /// Price per unit of the produce.
  final double pricePerUnit;
  
  /// Currency of the price (e.g., PHP).
  final String currency;
  
  /// Additional description or details about the produce.
  final String? description;
  
  /// Location where the produce can be picked up.
  final LocationData pickupLocation;
  
  /// URLs to photos of the produce.
  final List<String> photoUrls;
  
  /// Current status of the listing in the marketplace.
  final ProduceListingStatus status;
  
  /// Date when the produce was harvested.
  final DateTime? harvestTimestamp;
  
  /// Date when the listing will expire or is no longer valid.
  final DateTime? expiryTimestamp;
  
  /// Date when the listing was created.
  final DateTime createdAt;
  
  /// Date when the listing was last updated.
  final DateTime lastUpdated;
  
  /// Quantity tied up in active orders or accepted matches.
  final double quantityCommitted;
  
  /// Quantity that has been successfully sold and delivered.
  final double quantitySoldAndDelivered;

  /// Creates a new [ProduceListing].
  ///
  /// The [id] is optional and typically assigned by Firestore.
  /// The [farmerId], [produceName], [produceCategory], [quantity], [initialQuantity],
  /// [unit], [pricePerUnit], [currency], [pickupLocation], [status], [createdAt],
  /// and [lastUpdated] parameters are required.
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

  /// Creates a [ProduceListing] from Firestore document data.
  ///
  /// The [data] parameter contains the document fields, and [id] is the document ID.
  /// Handles type conversion and provides fallbacks for missing or invalid data.
  ///
  /// Throws an exception if critical data cannot be parsed.
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

  /// Converts this listing to a Firestore document.
  ///
  /// Creates a map of fields suitable for storing in Firestore.
  /// Only includes non-null fields to avoid storing unnecessary null values.
  ///
  /// Returns a Map containing the listing data ready for Firestore.
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

  /// Creates a copy of this listing with the specified fields replaced.
  ///
  /// Returns a new [ProduceListing] instance with updated fields while preserving
  /// the values of fields that are not specified.
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

Widget buildProduceListingItem({
  required BuildContext context, // Added context to access Theme
  required IconData iconData,
  required Color iconBgColor,
  required Color iconColor,
  required String title,
  required String categoryName,
  required double remainingQuantity,
  required String unit,
  required double pricePerUnit,
  required String currency,
  required ProduceListingStatus status,
  VoidCallback? onTap, // Optional: for making the card tappable
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  String quantityText = remainingQuantity > 0
      ? '${remainingQuantity.toStringAsFixed(1)} $unit left'
      : 'None left';

  if (status != ProduceListingStatus.available) {
    quantityText = status.displayName; // Override quantity text if not available
  }


  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0), // Adjusted horizontal margin
    elevation: 1.0,
    color: colorScheme.surfaceContainer, // Use themed card color
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))
    ),
    child: InkWell( // Make the card tappable
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: iconBgColor,
              child: Icon(iconData, color: iconColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryName,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quantityText,
                    style: textTheme.bodyMedium?.copyWith(
                        color: status == ProduceListingStatus.available && remainingQuantity > 0
                            ? colorScheme.secondary // Greenish for available quantity
                            : colorScheme.onSurfaceVariant.withOpacity(0.8), // Greyish for other statuses or none left
                        fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  NumberFormat.currency(locale: Intl.defaultLocale, symbol: '$currency ', decimalDigits: 2).format(pricePerUnit),
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'per $unit',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                if (status != ProduceListingStatus.available) // Show status explicitly if not available
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Chip(
                      label: Text(status.displayName, style: textTheme.labelSmall?.copyWith(color: colorScheme.onErrorContainer)),
                      backgroundColor: colorScheme.errorContainer.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      labelPadding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}