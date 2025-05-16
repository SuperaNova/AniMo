import * as admin from "firebase-admin";
import {LocationData} from "./aiMatchingTypes"; // Assuming LocationData is in aiMatchingTypes

export enum OrderStatus {
  PENDING_DRIVER_ASSIGNMENT = "pending_driver_assignment",
  CONFIRMED_AWAITING_PICKUP = "confirmed_awaiting_pickup",
  AWAITING_PICKUP = "awaiting_pickup", // If driver assigned but not yet picked up
  PICKED_UP_BY_DRIVER = "picked_up_by_driver",
  OUT_FOR_DELIVERY = "out_for_delivery",
  DELIVERED = "delivered",
  CANCELLED_BY_BUYER = "cancelled_by_buyer",
  CANCELLED_BY_FARMER = "cancelled_by_farmer",
  CANCELLED_BY_PLATFORM = "cancelled_by_platform",
  DELIVERY_FAILED = "delivery_failed",
  COMPLETED = "completed", // After successful delivery and payment settlement
  DISPUTED = "disputed",
}

export enum PaymentStatus {
  PENDING_COD = "pending_cod",
  PAID_COD = "paid_cod", // Driver collected COD
  PAYMENT_PROCESSING = "payment_processing", // For online payments
  PAYMENT_FAILED = "payment_failed",
  REFUNDED = "refunded",
  SETTLEMENT_PENDING_FARMER = "settlement_pending_farmer",
  SETTLEMENT_COMPLETE_FARMER = "settlement_complete_farmer",
}

export interface OrderDocData {
  // IDs and References
  listingId: string;
  listingRefPath: string;
  farmerId: string;
  buyerRequestId?: string; // Optional if order not from a specific buyer request
  buyerRequestRefPath?: string;
  buyerId: string;
  matchSuggestionId?: string; // ID of the MatchSuggestion that led to this order
  driverId?: string; // To be filled when a driver accepts

  // Produce Details (snapshot from listing/match)
  produceName: string;
  produceCategory: string;
  orderedQuantity: number;
  orderedQuantityUnit: string;

  // Pricing Details (snapshot from match/listing)
  pricePerUnit: number;
  totalPrice: number; // orderedQuantity * pricePerUnit
  // deliveryFee?: number; // To be added when calculated
  // platformFee?: number; // If applicable
  // finalAmountForBuyer?: number;
  // amountToRemitByDriver?: number;
  // payoutToFarmer?: number;

  // Timestamps
  orderTimestamp: admin.firestore.FieldValue; // serverTimestamp()
  lastUpdated: admin.firestore.FieldValue; // serverTimestamp()
  // expectedPickupTime?: admin.firestore.Timestamp;
  // actualPickupTime?: admin.firestore.Timestamp;
  // expectedDeliveryTime?: admin.firestore.Timestamp;
  // actualDeliveryTime?: admin.firestore.Timestamp;

  // Locations
  pickupLocation: LocationData; // Copied from listing
  deliveryLocation: LocationData; // Copied from buyer request / match suggestion

  // Statuses
  status: OrderStatus;
  paymentStatus: PaymentStatus;

  // Notes & Other Info
  // notesFromBuyer?: string;
  // notesFromFarmer?: string;
  // cancellationReason?: string;
}
