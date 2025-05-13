import 'package:cloud_firestore/cloud_firestore.dart';
import './location_data.dart'; // For pickup and delivery locations

// Nested class for Delivery Fee Details
class DeliveryFeeDetails {
  final double baseFee;
  final double? distanceKm;
  final double distanceSurcharge;
  final double? estimatedWeightKg;
  final double weightSurcharge;
  final double specialHandlingSurcharge; // Default to 0
  final double grossDeliveryFee;
  final double platformCommission; // AniMo's cut
  final double driverPayout; // What driver earns

  DeliveryFeeDetails({
    required this.baseFee,
    this.distanceKm,
    required this.distanceSurcharge,
    this.estimatedWeightKg,
    required this.weightSurcharge,
    this.specialHandlingSurcharge = 0.0,
    required this.grossDeliveryFee,
    this.platformCommission = 0.0, // Default to 0 for MVP
    required this.driverPayout,
  });

  factory DeliveryFeeDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      // Return default/empty object or throw error
      return DeliveryFeeDetails(baseFee: 0, distanceSurcharge: 0, weightSurcharge: 0, grossDeliveryFee: 0, driverPayout: 0);
    }
    return DeliveryFeeDetails(
      baseFee: (map['baseFee'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      distanceSurcharge: (map['distanceSurcharge'] as num?)?.toDouble() ?? 0.0,
      estimatedWeightKg: (map['estimatedWeightKg'] as num?)?.toDouble(),
      weightSurcharge: (map['weightSurcharge'] as num?)?.toDouble() ?? 0.0,
      specialHandlingSurcharge: (map['specialHandlingSurcharge'] as num?)?.toDouble() ?? 0.0,
      grossDeliveryFee: (map['grossDeliveryFee'] as num?)?.toDouble() ?? 0.0,
      platformCommission: (map['platformCommission'] as num?)?.toDouble() ?? 0.0,
      driverPayout: (map['driverPayout'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseFee': baseFee,
      if (distanceKm != null) 'distanceKm': distanceKm,
      'distanceSurcharge': distanceSurcharge,
      if (estimatedWeightKg != null) 'estimatedWeightKg': estimatedWeightKg,
      'weightSurcharge': weightSurcharge,
      'specialHandlingSurcharge': specialHandlingSurcharge,
      'grossDeliveryFee': grossDeliveryFee,
      'platformCommission': platformCommission,
      'driverPayout': driverPayout,
    };
  }
}

enum OrderStatus {
  pending_farmer_confirmation, // Initial state after AI match or direct buyer request from listing
  farmer_rejected,
  // awaiting_payment, // If pre-payment features are added in future
  awaiting_driver_assignment, // Farmer confirmed (or direct order implies this if farmer action not needed first)
  driver_assigned,
  awaiting_farmer_goods_handover, // Driver at pickup (Platform-Guaranteed Farmer Payment model)
  out_for_delivery, // Farmer confirmed goods handover to driver
  delivery_confirmed_by_driver, // Driver confirms drop-off
  delivery_confirmed_by_buyer, // Buyer confirms receipt of goods & COD
  completed, // All steps finalized, payments settled
  cancelled_by_buyer,
  cancelled_by_farmer,
  cancelled_by_system, // e.g., if listing expires, no driver found in time
}

String orderStatusToString(OrderStatus status) {
  return status.name;
}

OrderStatus orderStatusFromString(String? statusString) {
  return OrderStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => OrderStatus.pending_farmer_confirmation, // Default or error
      );
}

class Order {
  final String id; // Document ID
  final Timestamp orderCreationDateTime;

  final String buyerId;
  final String? buyerName;
  final String farmerId;
  final String? farmerName;
  final String listingId;

  // Snapshot of produce details
  final String produceName;
  final String produceCategory;
  final double orderedQuantity;
  final String orderedQuantityUnit;
  
  final double totalGoodsPrice; // Price for the produce itself (farmer's earning portion)
  final String? currency;

  final LocationData pickupLocation;
  final LocationData deliveryLocation;

  final OrderStatus status;

  // Timestamps for key events
  final Timestamp? farmerConfirmationTimestamp;
  final Timestamp? driverAssignmentTimestamp;
  final Timestamp? farmerGoodsHandoverTimestamp; // When farmer confirms goods given to driver
  final Timestamp? actualPickupTimeByDriver; // When driver confirms they picked up (can be same as above)
  final Timestamp? estimatedDeliveryTimeFromMaps; // Calculated by Maps API
  final Timestamp? actualDeliveryTimeByDriver; // Driver confirms drop-off
  final Timestamp? buyerConfirmationTimestamp; // Buyer confirms receipt
  final Timestamp? completionTimestamp;
  final Timestamp? cancellationTimestamp;

  final String? driverId;
  final String? driverName;

  final DeliveryFeeDetails? deliveryFeeDetails; // Will be populated by a cloud function
  final double? codAmountToCollectFromBuyer; // totalGoodsPrice + deliveryFeeDetails.driverPayout

  // Payment Details (for Platform-Guaranteed Farmer Payment model)
  final String paymentMethod; // e.g., "COD_PlatformGuaranteed"
  final String? paymentStatusGoods; // Tracks farmer's portion: e.g., "pending_platform_payout", "farmer_paid_by_platform"
  final String? paymentStatusDelivery; // Tracks driver's portion: e.g., "pending_driver_remittance", "driver_remittance_received" (for platform to get its share back from driver's COD collection)
  final String? overallPaymentStatus; // e.g., "pending_COD_collection", "partially_settled", "fully_settled"
  final Timestamp? farmerPaidByPlatformTimestamp;


  final String? originatingBuyerRequestId;
  final String? cancellationReason;
  final int? satisfactionRating; // Buyer's rating for this order (1-5)
  final String? satisfactionNotes;

  final String? notesForDriver;
  final String? notesForBuyer;
  final String? internalSystemNotes;
  final Timestamp lastUpdated;

  Order({
    required this.id,
    required this.orderCreationDateTime,
    required this.buyerId,
    this.buyerName,
    required this.farmerId,
    this.farmerName,
    required this.listingId,
    required this.produceName,
    required this.produceCategory,
    required this.orderedQuantity,
    required this.orderedQuantityUnit,
    required this.totalGoodsPrice,
    this.currency,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.status,
    this.farmerConfirmationTimestamp,
    this.driverAssignmentTimestamp,
    this.farmerGoodsHandoverTimestamp,
    this.actualPickupTimeByDriver,
    this.estimatedDeliveryTimeFromMaps,
    this.actualDeliveryTimeByDriver,
    this.buyerConfirmationTimestamp,
    this.completionTimestamp,
    this.cancellationTimestamp,
    this.driverId,
    this.driverName,
    this.deliveryFeeDetails,
    this.codAmountToCollectFromBuyer,
    this.paymentMethod = "COD_PlatformGuaranteed",
    this.paymentStatusGoods,
    this.paymentStatusDelivery,
    this.overallPaymentStatus,
    this.farmerPaidByPlatformTimestamp,
    this.originatingBuyerRequestId,
    this.cancellationReason,
    this.satisfactionRating,
    this.satisfactionNotes,
    this.notesForDriver,
    this.notesForBuyer,
    this.internalSystemNotes,
    required this.lastUpdated,
  });

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Order(
      id: doc.id,
      orderCreationDateTime: data['orderCreationDateTime'] as Timestamp? ?? Timestamp.now(),
      buyerId: data['buyerId'] as String,
      buyerName: data['buyerName'] as String?,
      farmerId: data['farmerId'] as String,
      farmerName: data['farmerName'] as String?,
      listingId: data['listingId'] as String,
      produceName: data['produceName'] as String,
      produceCategory: data['produceCategory'] as String,
      orderedQuantity: (data['orderedQuantity'] as num).toDouble(),
      orderedQuantityUnit: data['orderedQuantityUnit'] as String,
      totalGoodsPrice: (data['totalGoodsPrice'] as num).toDouble(),
      currency: data['currency'] as String?,
      pickupLocation: LocationData.fromMap(data['pickupLocation'] as Map<String, dynamic>?),
      deliveryLocation: LocationData.fromMap(data['deliveryLocation'] as Map<String, dynamic>?),
      status: orderStatusFromString(data['status'] as String?),
      farmerConfirmationTimestamp: data['farmerConfirmationTimestamp'] as Timestamp?,
      driverAssignmentTimestamp: data['driverAssignmentTimestamp'] as Timestamp?,
      farmerGoodsHandoverTimestamp: data['farmerGoodsHandoverTimestamp'] as Timestamp?,
      actualPickupTimeByDriver: data['actualPickupTimeByDriver'] as Timestamp?,
      estimatedDeliveryTimeFromMaps: data['estimatedDeliveryTimeFromMaps'] as Timestamp?,
      actualDeliveryTimeByDriver: data['actualDeliveryTimeByDriver'] as Timestamp?,
      buyerConfirmationTimestamp: data['buyerConfirmationTimestamp'] as Timestamp?,
      completionTimestamp: data['completionTimestamp'] as Timestamp?,
      cancellationTimestamp: data['cancellationTimestamp'] as Timestamp?,
      driverId: data['driverId'] as String?,
      driverName: data['driverName'] as String?,
      deliveryFeeDetails: DeliveryFeeDetails.fromMap(data['deliveryFeeDetails'] as Map<String, dynamic>?),
      codAmountToCollectFromBuyer: (data['codAmountToCollectFromBuyer'] as num?)?.toDouble(),
      paymentMethod: data['paymentMethod'] as String? ?? "COD_PlatformGuaranteed",
      paymentStatusGoods: data['paymentStatusGoods'] as String?,
      paymentStatusDelivery: data['paymentStatusDelivery'] as String?,
      overallPaymentStatus: data['overallPaymentStatus'] as String?,
      farmerPaidByPlatformTimestamp: data['farmerPaidByPlatformTimestamp'] as Timestamp?,
      originatingBuyerRequestId: data['originatingBuyerRequestId'] as String?,
      cancellationReason: data['cancellationReason'] as String?,
      satisfactionRating: data['satisfactionRating'] as int?,
      satisfactionNotes: data['satisfactionNotes'] as String?,
      notesForDriver: data['notesForDriver'] as String?,
      notesForBuyer: data['notesForBuyer'] as String?,
      internalSystemNotes: data['internalSystemNotes'] as String?,
      lastUpdated: data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderCreationDateTime': orderCreationDateTime,
      'buyerId': buyerId,
      if (buyerName != null) 'buyerName': buyerName,
      'farmerId': farmerId,
      if (farmerName != null) 'farmerName': farmerName,
      'listingId': listingId,
      'produceName': produceName,
      'produceCategory': produceCategory,
      'orderedQuantity': orderedQuantity,
      'orderedQuantityUnit': orderedQuantityUnit,
      'totalGoodsPrice': totalGoodsPrice,
      if (currency != null) 'currency': currency,
      'pickupLocation': pickupLocation.toMap(),
      'deliveryLocation': deliveryLocation.toMap(),
      'status': orderStatusToString(status),
      if (farmerConfirmationTimestamp != null) 'farmerConfirmationTimestamp': farmerConfirmationTimestamp,
      if (driverAssignmentTimestamp != null) 'driverAssignmentTimestamp': driverAssignmentTimestamp,
      if (farmerGoodsHandoverTimestamp != null) 'farmerGoodsHandoverTimestamp': farmerGoodsHandoverTimestamp,
      if (actualPickupTimeByDriver != null) 'actualPickupTimeByDriver': actualPickupTimeByDriver,
      if (estimatedDeliveryTimeFromMaps != null) 'estimatedDeliveryTimeFromMaps': estimatedDeliveryTimeFromMaps,
      if (actualDeliveryTimeByDriver != null) 'actualDeliveryTimeByDriver': actualDeliveryTimeByDriver,
      if (buyerConfirmationTimestamp != null) 'buyerConfirmationTimestamp': buyerConfirmationTimestamp,
      if (completionTimestamp != null) 'completionTimestamp': completionTimestamp,
      if (cancellationTimestamp != null) 'cancellationTimestamp': cancellationTimestamp,
      if (driverId != null) 'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (deliveryFeeDetails != null) 'deliveryFeeDetails': deliveryFeeDetails!.toMap(),
      if (codAmountToCollectFromBuyer != null) 'codAmountToCollectFromBuyer': codAmountToCollectFromBuyer,
      'paymentMethod': paymentMethod,
      if (paymentStatusGoods != null) 'paymentStatusGoods': paymentStatusGoods,
      if (paymentStatusDelivery != null) 'paymentStatusDelivery': paymentStatusDelivery,
      if (overallPaymentStatus != null) 'overallPaymentStatus': overallPaymentStatus,
      if (farmerPaidByPlatformTimestamp != null) 'farmerPaidByPlatformTimestamp': farmerPaidByPlatformTimestamp,
      if (originatingBuyerRequestId != null) 'originatingBuyerRequestId': originatingBuyerRequestId,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (satisfactionRating != null) 'satisfactionRating': satisfactionRating,
      if (satisfactionNotes != null) 'satisfactionNotes': satisfactionNotes,
      if (notesForDriver != null) 'notesForDriver': notesForDriver,
      if (notesForBuyer != null) 'notesForBuyer': notesForBuyer,
      if (internalSystemNotes != null) 'internalSystemNotes': internalSystemNotes,
      'lastUpdated': lastUpdated,
    };
  }
} 