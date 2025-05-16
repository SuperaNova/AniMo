/**
 * Import function triggers from their respective submodules:
 */
// Import and config modules
import * as functions from "firebase-functions"; // For logging
import { defineString } from "firebase-functions/params"; // For Firebase params/secrets
import { enableFirebaseTelemetry } from "@genkit-ai/firebase"; // For Firebase telemetry

// Initialize Firebase Admin 
import './admin'; // This will ensure Firebase is initialized before any other imports use it

// Import API key from registry
import { API_KEY } from './registry';

// Define the secret parameter (don't call .value() here)
const geminiApiKey = defineString("GEMINI_API_KEY");

// Try to initialize Genkit properly to avoid registry errors
try {
  // Log initialization
  functions.logger.info("Using Genkit with direct model configuration...");
  
  // For development testing, try fetching the key directly to validate it exists
  functions.logger.info(
    `API Key configuration: ${geminiApiKey ? "Parameter exists" : "Missing"}`
  );
  
  // Enable Firebase telemetry (must be called separately)
  enableFirebaseTelemetry().catch(err => {
    functions.logger.warn("Failed to enable Firebase telemetry:", err);
  });
  
  // Log that we successfully initialized
  functions.logger.info("Genkit API key is available", { 
    keyConfigured: !!API_KEY
  });
} catch (error) {
  functions.logger.error("Error initializing Genkit:", error);
}

// Export available Firestore Triggers
export * from "./firestore/handleAiMatching";
export * from "./firestore/handleOrderCreation";

// Restore missing functions - these will be implemented with placeholder functionality
import { REGION } from "./config";
import { onSchedule, ScheduledEvent } from "firebase-functions/v2/scheduler";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "./admin";

// Function to expire listings and requests that have passed their expiry date
export const expireListingsAndRequests = onSchedule({
  schedule: "every 12 hours",
  region: REGION,
}, async (event: ScheduledEvent): Promise<void> => {
  functions.logger.info("Scheduled function triggered: expireListingsAndRequests");
  
  const now = admin.firestore.Timestamp.now();
  
  // 1. Expire produce listings
  const expiredListingsQuery = db.collection("produceListings")
    .where("expiryTimestamp", "<=", now)
    .where("status", "in", ["available", "partially_committed"]);
  
  const expiredListingsSnapshot = await expiredListingsQuery.get();
  
  if (!expiredListingsSnapshot.empty) {
    const batch = db.batch();
    expiredListingsSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, { status: "expired" });
    });
    await batch.commit();
    functions.logger.info(`Expired ${expiredListingsSnapshot.size} produce listings`);
  }
  
  // 2. Expire buyer requests
  const expiredRequestsQuery = db.collection("buyerRequests")
    .where("expiryTimestamp", "<=", now)
    .where("status", "in", ["pending_match", "partially_fulfilled"]);
  
  const expiredRequestsSnapshot = await expiredRequestsQuery.get();
  
  if (!expiredRequestsSnapshot.empty) {
    const batch = db.batch();
    expiredRequestsSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, { status: "expired" });
    });
    await batch.commit();
    functions.logger.info(`Expired ${expiredRequestsSnapshot.size} buyer requests`);
  }
});

// Function to handle order status updates and trigger relevant actions
export const onOrderStatusUpdate = onDocumentUpdated({
  document: "orders/{orderId}",
  region: REGION,
}, async (event): Promise<void> => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  
  if (!before || !after) {
    functions.logger.error("Missing data in order update event");
    return;
  }
  
  const orderId = event.params.orderId;
  
  // Check if status has changed
  if (before.status === after.status) {
    functions.logger.info(`Order ${orderId} updated but status unchanged: ${after.status}`);
    return;
  }
  
  functions.logger.info(`Order ${orderId} status changed: ${before.status} -> ${after.status}`);
  
  // Handle different status transitions
  switch (after.status) {
    case "delivered":
      // Handle delivery completion
      functions.logger.info(`Order ${orderId} marked as delivered`);
      // TODO: Update related documents, notify users, etc.
      break;
      
    case "in_transit":
      // Handle transit start
      functions.logger.info(`Order ${orderId} is now in transit`);
      // TODO: Update related documents, notify users, etc.
      break;
      
    // Add other status cases as needed
  }
});

// Type definitions for the delivery fee calculator
interface DeliveryFeeData {
  distance: number;
  orderValue: number;
  weight?: number;
}

interface DeliveryFeeResult {
  baseFee: number;
  distanceFee: number;
  weightFee: number;
  discount: number;
  totalFee: number;
}

// Function to calculate delivery fee based on distance and order details
export const calculateDeliveryFee = onCall<DeliveryFeeData, DeliveryFeeResult>({
  region: REGION,
}, (request) => {
  // Ensure user is authenticated
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }
  
  // Extract parameters
  const { distance, orderValue, weight } = request.data;
  
  if (!distance || !orderValue) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function requires 'distance' and 'orderValue' parameters."
    );
  }
  
  // Simple calculation logic
  let baseFee = 5.00; // Base delivery fee
  let distanceFee = distance * 0.50; // $0.50 per km
  let weightFee = (weight && weight > 10) ? (weight - 10) * 0.20 : 0; // $0.20 per kg over 10kg
  
  // Apply discount for larger orders
  let discount = 0;
  if (orderValue > 100) {
    discount = orderValue * 0.05; // 5% discount for orders over $100
  }
  
  // Calculate total fee (with minimum fee of $5)
  const totalFee = Math.max(5, baseFee + distanceFee + weightFee - discount);
  
  return {
    baseFee,
    distanceFee,
    weightFee,
    discount,
    totalFee: parseFloat(totalFee.toFixed(2)),
  };
});
