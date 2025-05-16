import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import './location_data.dart'; // For pickup and delivery locations
import './produce_listing.dart'; // For ProduceCategory, ProduceListingStatus if needed directly

/// Represents the breakdown of delivery fees for an order.
///
/// Contains all components that make up the final delivery fee, including
/// base rates, surcharges, platform commission, and final payout to the driver.
class DeliveryFeeDetails {
  /// Base fee for delivery service before any additional charges.
  final double baseFee;
  
  /// Distance in kilometers between pickup and delivery locations.
  final double distanceKm;
  
  /// Additional charge based on distance.
  final double distanceSurcharge;
  
  /// Estimated weight of the order in kilograms, used for fee calculation.
  final double? estimatedWeightKg;
  
  /// Additional charge based on weight.
  final double weightSurcharge;
  
  /// Total delivery fee before platform commission (base + distance + weight).
  final double grossDeliveryFee; // base + distance + weight
  
  /// Percentage rate of platform commission (e.g., 0.10 for 10%).
  final double platformCommissionRate; // e.g. 0.10 for 10%
  
  /// Amount of commission taken by the platform.
  final double platformCommissionAmount; // grossDeliveryFee * platformCommissionRate
  
  /// Final amount paid to the driver (gross fee minus platform commission).
  final double driverPayout; // grossDeliveryFee - platformCommissionAmount

  /// Creates a new [DeliveryFeeDetails] instance.
  ///
  /// All parameters except [estimatedWeightKg] are required.
  DeliveryFeeDetails({
    required this.baseFee,
    required this.distanceKm,
    required this.distanceSurcharge,
    this.estimatedWeightKg,
    required this.weightSurcharge,
    required this.grossDeliveryFee,
    required this.platformCommissionRate,
    required this.platformCommissionAmount,
    required this.driverPayout,
  });

  /// Creates a [DeliveryFeeDetails] from a map of values.
  ///
  /// The [map] parameter contains the fee breakdown data.
  ///
  /// Returns a [DeliveryFeeDetails] instance populated with data from the map.
  factory DeliveryFeeDetails.fromMap(Map<String, dynamic> map) {
    return DeliveryFeeDetails(
      baseFee: (map['baseFee'] as num).toDouble(),
      distanceKm: (map['distanceKm'] as num).toDouble(),
      distanceSurcharge: (map['distanceSurcharge'] as num).toDouble(),
      estimatedWeightKg: (map['estimatedWeightKg'] as num?)?.toDouble(),
      weightSurcharge: (map['weightSurcharge'] as num).toDouble(),
      grossDeliveryFee: (map['grossDeliveryFee'] as num).toDouble(),
      platformCommissionRate: (map['platformCommissionRate'] as num).toDouble(),
      platformCommissionAmount: (map['platformCommissionAmount'] as num).toDouble(),
      driverPayout: (map['driverPayout'] as num).toDouble(),
    );
  }

  /// Converts this delivery fee details to a map.
  ///
  /// Creates a map representation with non-null fields for storing in Firestore.
  ///
  /// Returns a Map containing the fee details data.
  Map<String, dynamic> toMap() {
    return {
      'baseFee': baseFee,
      'distanceKm': distanceKm,
      'distanceSurcharge': distanceSurcharge,
      if (estimatedWeightKg != null) 'estimatedWeightKg': estimatedWeightKg,
      'weightSurcharge': weightSurcharge,
      'grossDeliveryFee': grossDeliveryFee,
      'platformCommissionRate': platformCommissionRate,
      'platformCommissionAmount': platformCommissionAmount,
      'driverPayout': driverPayout,
    };
  }
}

/// Status of an order in the order fulfillment lifecycle.
///
/// Tracks the progression of an order from initial confirmation to final completion,
/// including delivery states and cancellation/failure scenarios.
enum OrderStatus {
  /// Initial status after order creation, awaiting confirmation.
  pending_confirmation('Pending Confirmation'), // Initial status after creation from match
  
  /// Order has been confirmed by AniMo platform and is ready for a driver.
  confirmed_by_platform('Confirmed by Platform'), // AniMo admin confirms, ready for driver
  
  /// System is looking for an available driver to assign.
  searching_for_driver('Searching for Driver'),
  
  /// A driver has been assigned to the order.
  driver_assigned('Driver Assigned'),
  
  /// Driver is traveling to the pickup location.
  driver_en_route_to_pickup('Driver En Route to Pickup'),
  
  /// Driver has arrived at the pickup location.
  at_pickup_location('Driver at Pickup Location'),
  
  /// Driver has picked up the produce.
  picked_up('Produce Picked Up'),
  
  /// Driver is traveling to the delivery location.
  en_route_to_delivery('En Route to Delivery'),
  
  /// Driver has arrived at the delivery location.
  at_delivery_location('Driver at Delivery Location'),
  
  /// Produce has been delivered and buyer has confirmed receipt.
  delivered('Delivered'), // Buyer confirms receipt
  
  /// Order is finalized with payment settled and farmer paid.
  completed('Completed'), // Payment settled, farmer paid (final success state)
  
  /// Order was cancelled by the buyer.
  cancelled_by_buyer('Cancelled by Buyer'),
  
  /// Order was cancelled by the farmer.
  cancelled_by_farmer('Cancelled by Farmer'),
  
  /// Order was cancelled by the platform (e.g., due to no driver, issues).
  cancelled_by_platform('Cancelled by Platform'), // e.g., due to no driver, issue
  
  /// Driver attempted but could not deliver the order.
  failed_delivery('Failed Delivery'), // Driver attempted but could not deliver
  
  /// Order is under dispute resolution.
  disputed('Disputed');

  /// Creates an order status with a display name.
  const OrderStatus(this.displayName);
  
  /// Human-readable name for this status.
  final String displayName;
}

/// Type of payment method for an order.
///
/// Indicates whether payment will be collected upon delivery or made online.
enum PaymentType {
  /// Payment will be collected in cash when the order is delivered.
  cod('Cash on Delivery'),
  
  /// Payment will be made through an online payment gateway.
  online('Online Payment');

  /// Creates a payment type with a display name.
  const PaymentType(this.displayName);
  
  /// Human-readable name for this payment type.
  final String displayName;
}

/// Status of the payment for an order.
///
/// Tracks the state of payment processing for the order.
enum PaymentStatus {
  /// Payment has not yet been processed.
  pending('Pending'), // For COD: pending collection. For Online: pending gateway confirmation.
  
  /// Cash payment has been collected from the buyer (COD only).
  collected_from_buyer('Collected from Buyer (COD)'), // Driver has cash
  
  /// Payment has been disbursed to the farmer.
  paid_to_farmer('Paid to Farmer'),
  
  /// Payment has been disbursed to the driver.
  paid_to_driver('Paid to Driver'),
  
  /// Platform commission has been collected.
  platform_fee_collected('Platform Fee Collected'),
  
  /// Payment has been refunded to the buyer.
  refunded('Refunded'),
  
  /// Payment processing failed.
  failed('Payment Failed');

  /// Creates a payment status with a display name.
  const PaymentStatus(this.displayName);
  
  /// Human-readable name for this payment status.
  final String displayName;
}

/// Converts an [OrderStatus] to its string representation.
///
/// Returns the display name of the status.
String orderStatusToString(OrderStatus status) {
  return status.displayName;
}

/// Converts a string to an [OrderStatus].
///
/// The [statusString] should match the name of a status enum value.
/// Returns the status value matching the string, or [OrderStatus.pending_confirmation]
/// if no match is found.
OrderStatus orderStatusFromString(String? statusString) {
  return OrderStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => OrderStatus.pending_confirmation, // Default or error
      );
}

/// Represents an order in the system.
///
/// Contains all information about an order between a buyer and farmer,
/// including details about the produce, pricing, delivery, payment,
/// and current status. This model manages the entire lifecycle of an order
/// from creation to completion.
class Order {
  /// Unique identifier for the order.
  final String? id;
  
  /// ID of the produce listing this order is for.
  final String produceListingId;
  
  /// ID of the farmer selling the produce.
  final String farmerId;
  
  /// ID of the buyer purchasing the produce.
  final String buyerId;
  
  /// ID of the match suggestion that generated this order (if applicable).
  final String? matchSuggestionId; // Optional, if order came from a suggestion

  // Snapshot of produce details at time of order
  /// Name of the produce being ordered.
  final String produceName;
  
  /// Category of the produce.
  final ProduceCategory produceCategory;
  
  /// Custom category name if [produceCategory] is [ProduceCategory.other].
  final String? customProduceCategory;
  
  /// Quantity of produce ordered.
  final double orderedQuantity;
  
  /// Unit of measurement (e.g., kg, piece, bundle, sack).
  final String unit;
  
  /// Price per unit of the produce.
  final double pricePerUnit;
  
  /// Currency of the price (e.g., PHP).
  final String currency;
  
  /// Total cost of the produce (orderedQuantity * pricePerUnit).
  final double totalGoodsPrice; // orderedQuantity * pricePerUnit

  /// Location where the produce will be picked up from the farmer.
  final LocationData pickupLocation; // Snapshot or direct reference
  
  /// Location where the produce will be delivered to the buyer.
  final LocationData deliveryLocation;

  /// Current status of the order.
  final OrderStatus status;
  
  /// History of status changes for this order.
  final List<OrderStatusUpdate> statusHistory;

  /// ID of the driver assigned to deliver this order.
  final String? assignedDriverId;
  
  /// Breakdown of delivery fees for this order.
  final DeliveryFeeDetails? deliveryFeeDetails;
  
  /// Total amount to be paid (produce cost + delivery fee).
  final double totalOrderAmount; // totalGoodsPrice + (deliveryFeeDetails?.grossDeliveryFee ?? 0)
  
  /// Amount to be collected from the buyer for COD orders.
  final double codAmountToCollectFromBuyer; // If COD, this is totalOrderAmount

  /// Type of payment method for this order.
  final PaymentType paymentType;
  
  /// Status of payment for the produce portion of the order.
  final PaymentStatus paymentStatusGoods; // For the goods part, farmer payout
  
  /// Status of payment for the delivery portion of the order.
  final PaymentStatus paymentStatusDelivery; // For the delivery part, driver payout
  
  /// ID of the payment transaction (for online payments).
  final String? paymentTransactionId; // For online payments

  /// Date and time when the order was created.
  final DateTime createdAt;
  
  /// Date and time when the order was last updated.
  final DateTime lastUpdated;
  
  /// Estimated time when the produce will be picked up.
  final DateTime? estimatedPickupTime;
  
  /// Estimated time when the produce will be delivered.
  final DateTime? estimatedDeliveryTime;
  
  /// Actual time when the produce was picked up.
  final DateTime? actualPickupTime;
  
  /// Actual time when the produce was delivered.
  final DateTime? actualDeliveryTime;

  /// Additional notes from the buyer about the order.
  final String? buyerNotes;
  
  /// Additional notes from the farmer about the order.
  final String? farmerNotes;
  
  /// Additional notes from the driver about the order.
  final String? driverNotes;
  
  /// Notes from the platform administrators about the order.
  final String? platformNotes; // For admin/system notes

  /// Rating (1-5) given by the buyer to the farmer.
  final int? buyerRatingForFarmer;
  
  /// Review text given by the buyer to the farmer.
  final String? buyerReviewForFarmer;
  
  /// Rating (1-5) given by the buyer to the driver.
  final int? buyerRatingForDriver;
  
  /// Review text given by the buyer to the driver.
  final String? buyerReviewForDriver;
  
  /// Rating (1-5) given by the farmer to the buyer.
  final int? farmerRatingForBuyer;
  
  /// Review text given by the farmer to the buyer.
  final String? farmerReviewForBuyer;
  
  /// Rating (1-5) given by the farmer to the driver.
  final int? farmerRatingForDriver;
  
  /// Review text given by the farmer to the driver.
  final String? farmerReviewForDriver;
  
  /// Rating (1-5) given by the driver to the buyer.
  final int? driverRatingForBuyer;
  
  /// Review text given by the driver to the buyer.
  final String? driverReviewForBuyer;
  
  /// Rating (1-5) given by the driver to the farmer.
  final int? driverRatingForFarmer;
  
  /// Review text given by the driver to the farmer.
  final String? driverReviewForFarmer;

  /// Creates a new [Order] instance.
  ///
  /// The core order details including IDs, produce information, locations,
  /// status, payment information, and timestamps are required. Other parameters
  /// are optional and may be populated as the order progresses.
  Order({
    this.id,
    required this.produceListingId,
    required this.farmerId,
    required this.buyerId,
    this.matchSuggestionId,
    required this.produceName,
    required this.produceCategory,
    this.customProduceCategory,
    required this.orderedQuantity,
    required this.unit,
    required this.pricePerUnit,
    required this.currency,
    required this.totalGoodsPrice,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.status,
    this.statusHistory = const [],
    this.assignedDriverId,
    this.deliveryFeeDetails,
    required this.totalOrderAmount,
    required this.codAmountToCollectFromBuyer,
    required this.paymentType,
    required this.paymentStatusGoods,
    required this.paymentStatusDelivery,
    this.paymentTransactionId,
    required this.createdAt,
    required this.lastUpdated,
    this.estimatedPickupTime,
    this.estimatedDeliveryTime,
    this.actualPickupTime,
    this.actualDeliveryTime,
    this.buyerNotes,
    this.farmerNotes,
    this.driverNotes,
    this.platformNotes,
    this.buyerRatingForFarmer,
    this.buyerReviewForFarmer,
    this.buyerRatingForDriver,
    this.buyerReviewForDriver,
    this.farmerRatingForBuyer,
    this.farmerReviewForBuyer,
    this.farmerRatingForDriver,
    this.farmerReviewForDriver,
    this.driverRatingForBuyer,
    this.driverReviewForBuyer,
    this.driverRatingForFarmer,
    this.driverReviewForFarmer,
  });

  /// Creates an [Order] from Firestore document data.
  ///
  /// Converts Firestore document data into an Order instance.
  /// The [data] parameter contains the document fields, and [id] is the document ID.
  ///
  /// Returns an [Order] instance populated with data from Firestore.
  factory Order.fromFirestore(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      produceListingId: data['produceListingId'] as String,
      farmerId: data['farmerId'] as String,
      buyerId: data['buyerId'] as String,
      matchSuggestionId: data['matchSuggestionId'] as String?,
      produceName: data['produceName'] as String,
      produceCategory: ProduceCategory.values.firstWhere(
        (e) => e.name == data['produceCategory'],
        orElse: () => ProduceCategory.other, // Default or handle error
      ),
      customProduceCategory: data['customProduceCategory'] as String?,
      orderedQuantity: (data['orderedQuantity'] as num).toDouble(),
      unit: data['unit'] as String,
      pricePerUnit: (data['pricePerUnit'] as num).toDouble(),
      currency: data['currency'] as String,
      totalGoodsPrice: (data['totalGoodsPrice'] as num).toDouble(),
      pickupLocation: LocationData.fromMap(data['pickupLocation'] as Map<String, dynamic>),
      deliveryLocation: LocationData.fromMap(data['deliveryLocation'] as Map<String, dynamic>),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending_confirmation,
      ),
      statusHistory: (data['statusHistory'] as List<dynamic>? ?? [])
          .map((item) => OrderStatusUpdate.fromMap(item as Map<String, dynamic>))
          .toList(),
      assignedDriverId: data['assignedDriverId'] as String?,
      deliveryFeeDetails: data['deliveryFeeDetails'] != null
          ? DeliveryFeeDetails.fromMap(data['deliveryFeeDetails'] as Map<String, dynamic>)
          : null,
      totalOrderAmount: (data['totalOrderAmount'] as num).toDouble(),
      codAmountToCollectFromBuyer: (data['codAmountToCollectFromBuyer'] as num).toDouble(),
      paymentType: PaymentType.values.firstWhere(
        (e) => e.name == data['paymentType'],
        orElse: () => PaymentType.cod,
      ),
      paymentStatusGoods: PaymentStatus.values.firstWhere(
        (e) => e.name == data['paymentStatusGoods'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentStatusDelivery: PaymentStatus.values.firstWhere(
        (e) => e.name == data['paymentStatusDelivery'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentTransactionId: data['paymentTransactionId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      estimatedPickupTime: (data['estimatedPickupTime'] as Timestamp?)?.toDate(),
      estimatedDeliveryTime: (data['estimatedDeliveryTime'] as Timestamp?)?.toDate(),
      actualPickupTime: (data['actualPickupTime'] as Timestamp?)?.toDate(),
      actualDeliveryTime: (data['actualDeliveryTime'] as Timestamp?)?.toDate(),
      buyerNotes: data['buyerNotes'] as String?,
      farmerNotes: data['farmerNotes'] as String?,
      driverNotes: data['driverNotes'] as String?,
      platformNotes: data['platformNotes'] as String?,
      buyerRatingForFarmer: data['buyerRatingForFarmer'] as int?,
      buyerReviewForFarmer: data['buyerReviewForFarmer'] as String?,
      buyerRatingForDriver: data['buyerRatingForDriver'] as int?,
      buyerReviewForDriver: data['buyerReviewForDriver'] as String?,
      farmerRatingForBuyer: data['farmerRatingForBuyer'] as int?,
      farmerReviewForBuyer: data['farmerReviewForBuyer'] as String?,
      farmerRatingForDriver: data['farmerRatingForDriver'] as int?,
      farmerReviewForDriver: data['farmerReviewForDriver'] as String?,
      driverRatingForBuyer: data['driverRatingForBuyer'] as int?,
      driverReviewForBuyer: data['driverReviewForBuyer'] as String?,
      driverRatingForFarmer: data['driverRatingForFarmer'] as int?,
      driverReviewForFarmer: data['driverReviewForFarmer'] as String?,
    );
  }

  /// Converts this order to a Firestore document.
  ///
  /// Creates a map of fields suitable for storing in Firestore.
  /// Only includes non-null fields to avoid storing unnecessary null values.
  ///
  /// Returns a Map containing the order data ready for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'produceListingId': produceListingId,
      'farmerId': farmerId,
      'buyerId': buyerId,
      if (matchSuggestionId != null) 'matchSuggestionId': matchSuggestionId,
      'produceName': produceName,
      'produceCategory': produceCategory.name,
      if (customProduceCategory != null) 'customProduceCategory': customProduceCategory,
      'orderedQuantity': orderedQuantity,
      'unit': unit,
      'pricePerUnit': pricePerUnit,
      'currency': currency,
      'totalGoodsPrice': totalGoodsPrice,
      'pickupLocation': pickupLocation.toMap(),
      'deliveryLocation': deliveryLocation.toMap(),
      'status': status.name,
      'statusHistory': statusHistory.map((item) => item.toMap()).toList(),
      if (assignedDriverId != null) 'assignedDriverId': assignedDriverId,
      if (deliveryFeeDetails != null) 'deliveryFeeDetails': deliveryFeeDetails!.toMap(),
      'totalOrderAmount': totalOrderAmount,
      'codAmountToCollectFromBuyer': codAmountToCollectFromBuyer,
      'paymentType': paymentType.name,
      'paymentStatusGoods': paymentStatusGoods.name,
      'paymentStatusDelivery': paymentStatusDelivery.name,
      if (paymentTransactionId != null) 'paymentTransactionId': paymentTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      if (estimatedPickupTime != null) 'estimatedPickupTime': Timestamp.fromDate(estimatedPickupTime!),
      if (estimatedDeliveryTime != null) 'estimatedDeliveryTime': Timestamp.fromDate(estimatedDeliveryTime!),
      if (actualPickupTime != null) 'actualPickupTime': Timestamp.fromDate(actualPickupTime!),
      if (actualDeliveryTime != null) 'actualDeliveryTime': Timestamp.fromDate(actualDeliveryTime!),
      if (buyerNotes != null) 'buyerNotes': buyerNotes,
      if (farmerNotes != null) 'farmerNotes': farmerNotes,
      if (driverNotes != null) 'driverNotes': driverNotes,
      if (platformNotes != null) 'platformNotes': platformNotes,
      if (buyerRatingForFarmer != null) 'buyerRatingForFarmer': buyerRatingForFarmer,
      if (buyerReviewForFarmer != null) 'buyerReviewForFarmer': buyerReviewForFarmer,
      if (buyerRatingForDriver != null) 'buyerRatingForDriver': buyerRatingForDriver,
      if (buyerReviewForDriver != null) 'buyerReviewForDriver': buyerReviewForDriver,
      if (farmerRatingForBuyer != null) 'farmerRatingForBuyer': farmerRatingForBuyer,
      if (farmerReviewForBuyer != null) 'farmerReviewForBuyer': farmerReviewForBuyer,
      if (farmerRatingForDriver != null) 'farmerRatingForDriver': farmerRatingForDriver,
      if (farmerReviewForDriver != null) 'farmerReviewForDriver': farmerReviewForDriver,
      if (driverRatingForBuyer != null) 'driverRatingForBuyer': driverRatingForBuyer,
      if (driverReviewForBuyer != null) 'driverReviewForBuyer': driverReviewForBuyer,
      if (driverRatingForFarmer != null) 'driverRatingForFarmer': driverRatingForFarmer,
      if (driverReviewForFarmer != null) 'driverReviewForFarmer': driverReviewForFarmer,
    };
  }
  
  /// Creates a copy of this order with the specified fields replaced.
  ///
  /// Returns a new [Order] instance with updated fields while preserving
  /// the values of fields that are not specified.
  Order copyWith({
    String? id,
    String? produceListingId,
    String? farmerId,
    String? buyerId,
    String? matchSuggestionId,
    String? produceName,
    ProduceCategory? produceCategory,
    String? customProduceCategory,
    double? orderedQuantity,
    String? unit,
    double? pricePerUnit,
    String? currency,
    double? totalGoodsPrice,
    LocationData? pickupLocation,
    LocationData? deliveryLocation,
    OrderStatus? status,
    List<OrderStatusUpdate>? statusHistory,
    String? assignedDriverId,
    DeliveryFeeDetails? deliveryFeeDetails,
    double? totalOrderAmount,
    double? codAmountToCollectFromBuyer,
    PaymentType? paymentType,
    PaymentStatus? paymentStatusGoods,
    PaymentStatus? paymentStatusDelivery,
    String? paymentTransactionId,
    DateTime? createdAt,
    DateTime? lastUpdated,
    DateTime? estimatedPickupTime,
    DateTime? estimatedDeliveryTime,
    DateTime? actualPickupTime,
    DateTime? actualDeliveryTime,
    String? buyerNotes,
    String? farmerNotes,
    String? driverNotes,
    String? platformNotes,
    int? buyerRatingForFarmer,
    String? buyerReviewForFarmer,
    int? buyerRatingForDriver,
    String? buyerReviewForDriver,
    int? farmerRatingForBuyer,
    String? farmerReviewForBuyer,
    int? farmerRatingForDriver,
    String? farmerReviewForDriver,
    int? driverRatingForBuyer,
    String? driverReviewForBuyer,
    int? driverRatingForFarmer,
    String? driverReviewForFarmer,
  }) {
    return Order(
      id: id ?? this.id,
      produceListingId: produceListingId ?? this.produceListingId,
      farmerId: farmerId ?? this.farmerId,
      buyerId: buyerId ?? this.buyerId,
      matchSuggestionId: matchSuggestionId ?? this.matchSuggestionId,
      produceName: produceName ?? this.produceName,
      produceCategory: produceCategory ?? this.produceCategory,
      customProduceCategory: customProduceCategory ?? this.customProduceCategory,
      orderedQuantity: orderedQuantity ?? this.orderedQuantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      currency: currency ?? this.currency,
      totalGoodsPrice: totalGoodsPrice ?? this.totalGoodsPrice,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      deliveryFeeDetails: deliveryFeeDetails ?? this.deliveryFeeDetails,
      totalOrderAmount: totalOrderAmount ?? this.totalOrderAmount,
      codAmountToCollectFromBuyer: codAmountToCollectFromBuyer ?? this.codAmountToCollectFromBuyer,
      paymentType: paymentType ?? this.paymentType,
      paymentStatusGoods: paymentStatusGoods ?? this.paymentStatusGoods,
      paymentStatusDelivery: paymentStatusDelivery ?? this.paymentStatusDelivery,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      estimatedPickupTime: estimatedPickupTime ?? this.estimatedPickupTime,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualPickupTime: actualPickupTime ?? this.actualPickupTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      buyerNotes: buyerNotes ?? this.buyerNotes,
      farmerNotes: farmerNotes ?? this.farmerNotes,
      driverNotes: driverNotes ?? this.driverNotes,
      platformNotes: platformNotes ?? this.platformNotes,
      buyerRatingForFarmer: buyerRatingForFarmer ?? this.buyerRatingForFarmer,
      buyerReviewForFarmer: buyerReviewForFarmer ?? this.buyerReviewForFarmer,
      buyerRatingForDriver: buyerRatingForDriver ?? this.buyerRatingForDriver,
      buyerReviewForDriver: buyerReviewForDriver ?? this.buyerReviewForDriver,
      farmerRatingForBuyer: farmerRatingForBuyer ?? this.farmerRatingForBuyer,
      farmerReviewForBuyer: farmerReviewForBuyer ?? this.farmerReviewForBuyer,
      farmerRatingForDriver: farmerRatingForDriver ?? this.farmerRatingForDriver,
      farmerReviewForDriver: farmerReviewForDriver ?? this.farmerReviewForDriver,
      driverRatingForBuyer: driverRatingForBuyer ?? this.driverRatingForBuyer,
      driverReviewForBuyer: driverReviewForBuyer ?? this.driverReviewForBuyer,
      driverRatingForFarmer: driverRatingForFarmer ?? this.driverRatingForFarmer,
      driverReviewForFarmer: driverReviewForFarmer ?? this.driverReviewForFarmer,
    );
  }
}

/// Records a status change in an order's lifecycle.
///
/// Maintains the history of status updates with timestamps, who made the change,
/// and optional reasons, enabling a complete audit trail of the order.
class OrderStatusUpdate {
  /// The new status that was applied to the order.
  final OrderStatus status;
  
  /// When the status update occurred.
  final DateTime timestamp;
  
  /// User ID of the person who updated the status.
  final String? updatedBy; // UID of user/system that made the update
  
  /// Optional reason or note explaining why the status was changed.
  final String? reason; // Optional reason for status change

  /// Creates a new [OrderStatusUpdate].
  ///
  /// The [status] and [timestamp] parameters are required.
  /// The [updatedBy] and [reason] parameters are optional.
  OrderStatusUpdate({
    required this.status,
    required this.timestamp,
    this.updatedBy,
    this.reason,
  });

  /// Creates an [OrderStatusUpdate] from a map of values.
  ///
  /// The [map] parameter contains the status update data.
  ///
  /// Returns an [OrderStatusUpdate] instance populated with data from the map.
  factory OrderStatusUpdate.fromMap(Map<String, dynamic> map) {
    return OrderStatusUpdate(
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.pending_confirmation, // Default status
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      updatedBy: map['updatedBy'] as String?,
      reason: map['reason'] as String?,
    );
  }

  /// Converts this status update to a map.
  ///
  /// Creates a map representation with non-null fields for storing in Firestore.
  ///
  /// Returns a Map containing the status update data.
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (reason != null) 'reason': reason,
    };
  }
}

/// Returns styling information for displaying an order status.
///
/// The [status] parameter specifies which order status to style.
/// The [colorScheme] parameter provides the app's color scheme for theming.
///
/// Returns a map containing an icon, main color, and background color for the status.
Map<String, dynamic> getStyleForOrderStatus(OrderStatus status, ColorScheme colorScheme) {
  switch (status) {
    case OrderStatus.pending_confirmation:
      return {'icon': Icons.hourglass_empty_outlined, 'color': colorScheme.tertiary, 'bgColor': colorScheme.tertiaryContainer.withOpacity(0.3)};
    case OrderStatus.confirmed_by_platform:
      return {'icon': Icons.playlist_add_check_circle_outlined, 'color': colorScheme.primary, 'bgColor': colorScheme.primaryContainer.withOpacity(0.3)};
    case OrderStatus.searching_for_driver:
      return {'icon': Icons.person_search_outlined, 'color': Colors.blueGrey[700]!, 'bgColor': Colors.blueGrey[100]!};
    case OrderStatus.driver_assigned:
      return {'icon': Icons.two_wheeler_outlined, 'color': colorScheme.secondary, 'bgColor': colorScheme.secondaryContainer.withOpacity(0.3)};
    case OrderStatus.driver_en_route_to_pickup:
    case OrderStatus.en_route_to_delivery:
      return {'icon': Icons.route_outlined, 'color': Colors.cyan[700]!, 'bgColor': Colors.cyan[100]!};
    case OrderStatus.at_pickup_location:
    case OrderStatus.at_delivery_location:
      return {'icon': Icons.storefront_outlined, 'color': Colors.brown[600]!, 'bgColor': Colors.brown[100]!};
    case OrderStatus.picked_up:
      return {'icon': Icons.takeout_dining_outlined, 'color': Colors.lime[800]!, 'bgColor': Colors.lime[100]!};
    case OrderStatus.delivered:
      return {'icon': Icons.local_shipping_outlined, 'color': Colors.lightGreen[700]!, 'bgColor': Colors.lightGreen[100]!};
    case OrderStatus.completed:
      return {'icon': Icons.check_circle_outline, 'color': colorScheme.secondary, 'bgColor': colorScheme.secondaryContainer.withOpacity(0.3)};
    case OrderStatus.cancelled_by_buyer:
    case OrderStatus.cancelled_by_farmer:
    case OrderStatus.cancelled_by_platform:
    case OrderStatus.failed_delivery:
    case OrderStatus.disputed:
      return {'icon': Icons.error_outline, 'color': colorScheme.error, 'bgColor': colorScheme.errorContainer.withOpacity(0.3)};
    default:
      return {'icon': Icons.info_outline, 'color': colorScheme.onSurfaceVariant, 'bgColor': colorScheme.surfaceVariant.withOpacity(0.3)};
  }
}