import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import './location_data.dart'; // For pickup and delivery locations
import './produce_listing.dart'; // For ProduceCategory, ProduceListingStatus if needed directly

// Nested class for Delivery Fee Details
class DeliveryFeeDetails {
  final double baseFee;
  final double distanceKm;
  final double distanceSurcharge;
  final double? estimatedWeightKg;
  final double weightSurcharge;
  final double grossDeliveryFee; // base + distance + weight
  final double platformCommissionRate; // e.g. 0.10 for 10%
  final double platformCommissionAmount; // grossDeliveryFee * platformCommissionRate
  final double driverPayout; // grossDeliveryFee - platformCommissionAmount

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

// Enums for Order
enum OrderStatus {
  pending_confirmation('Pending Confirmation'), // Initial status after creation from match
  confirmed_by_platform('Confirmed by Platform'), // AniMo admin confirms, ready for driver
  searching_for_driver('Searching for Driver'),
  driver_assigned('Driver Assigned'),
  driver_en_route_to_pickup('Driver En Route to Pickup'),
  at_pickup_location('Driver at Pickup Location'),
  picked_up('Produce Picked Up'),
  en_route_to_delivery('En Route to Delivery'),
  at_delivery_location('Driver at Delivery Location'),
  delivered('Delivered'), // Buyer confirms receipt
  completed('Completed'), // Payment settled, farmer paid (final success state)
  cancelled_by_buyer('Cancelled by Buyer'),
  cancelled_by_farmer('Cancelled by Farmer'),
  cancelled_by_platform('Cancelled by Platform'), // e.g., due to no driver, issue
  failed_delivery('Failed Delivery'), // Driver attempted but could not deliver
  disputed('Disputed');

  const OrderStatus(this.displayName);
  final String displayName;
}

enum PaymentType {
  cod('Cash on Delivery'),
  online('Online Payment');

  const PaymentType(this.displayName);
  final String displayName;
}

enum PaymentStatus {
  pending('Pending'), // For COD: pending collection. For Online: pending gateway confirmation.
  collected_from_buyer('Collected from Buyer (COD)'), // Driver has cash
  paid_to_farmer('Paid to Farmer'),
  paid_to_driver('Paid to Driver'),
  platform_fee_collected('Platform Fee Collected'),
  refunded('Refunded'),
  failed('Payment Failed');

  const PaymentStatus(this.displayName);
  final String displayName;
}

String orderStatusToString(OrderStatus status) {
  return status.displayName;
}

OrderStatus orderStatusFromString(String? statusString) {
  return OrderStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => OrderStatus.pending_confirmation, // Default or error
      );
}

class Order {
  final String? id;
  final String produceListingId;
  final String farmerId;
  final String buyerId;
  final String? matchSuggestionId; // Optional, if order came from a suggestion

  // Snapshot of produce details at time of order
  final String produceName;
  final ProduceCategory produceCategory;
  final String? customProduceCategory;
  final double orderedQuantity;
  final String unit;
  final double pricePerUnit;
  final String currency;
  final double totalGoodsPrice; // orderedQuantity * pricePerUnit

  final LocationData pickupLocation; // Snapshot or direct reference
  final LocationData deliveryLocation;

  final OrderStatus status;
  final List<OrderStatusUpdate> statusHistory;

  final String? assignedDriverId;
  final DeliveryFeeDetails? deliveryFeeDetails;
  final double totalOrderAmount; // totalGoodsPrice + (deliveryFeeDetails?.grossDeliveryFee ?? 0)
  final double codAmountToCollectFromBuyer; // If COD, this is totalOrderAmount

  final PaymentType paymentType;
  final PaymentStatus paymentStatusGoods; // For the goods part, farmer payout
  final PaymentStatus paymentStatusDelivery; // For the delivery part, driver payout
  final String? paymentTransactionId; // For online payments

  final DateTime createdAt;
  final DateTime lastUpdated;
  final DateTime? estimatedPickupTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualPickupTime;
  final DateTime? actualDeliveryTime;

  final String? buyerNotes;
  final String? farmerNotes;
  final String? driverNotes;
  final String? platformNotes; // For admin/system notes

  final int? buyerRatingForFarmer;
  final String? buyerReviewForFarmer;
  final int? buyerRatingForDriver;
  final String? buyerReviewForDriver;
  final int? farmerRatingForBuyer;
  final String? farmerReviewForBuyer;
  final int? farmerRatingForDriver;
  final String? farmerReviewForDriver;
  final int? driverRatingForBuyer;
  final String? driverReviewForBuyer;
  final int? driverRatingForFarmer;
  final String? driverReviewForFarmer;

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

// Helper class for status history (if not already defined elsewhere)
class OrderStatusUpdate {
  final OrderStatus status;
  final DateTime timestamp;
  final String? updatedBy; // UID of user/system that made the update
  final String? reason; // Optional reason for status change

  OrderStatusUpdate({
    required this.status,
    required this.timestamp,
    this.updatedBy,
    this.reason,
  });

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

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (reason != null) 'reason': reason,
    };
  }
}

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