import * as admin from "firebase-admin";

// Simplified LocationData, assuming it might have geohash for queries
export interface LocationData {
  latitude: number;
  longitude: number;
  address?: string;
  geohash?: string;
}

// Data structure for ProduceListings in Firestore (excluding ID)
export interface ProduceListingDocData {
  farmerId: string;
  farmerName: string; // Denormalized
  produceName: string;
  produceCategory: string;
  quantity: number;
  quantityUnit: string;
  pricePerUnit: number;
  description?: string;
  images?: string[]; // URLs to images in Firebase Storage
  location: LocationData;
  listingTimestamp: admin.firestore.Timestamp;
  expiryTimestamp: admin.firestore.Timestamp;
  status: "available" | "partially_committed" | "fulfilled" | "expired" | "cancelled";
  // Add any other fields relevant for matching by the AI
}

// Data structure for BuyerRequests in Firestore (excluding ID)
export interface BuyerRequestDocData {
  buyerId: string;
  buyerName: string; // Denormalized
  produceName: string;
  produceCategory: string;
  desiredQuantity: number;
  desiredQuantityUnit: string;
  desiredPricePerUnit?: number;
  deliveryLocation: LocationData;
  deliveryDeadline: admin.firestore.Timestamp;
  requestTimestamp: admin.firestore.Timestamp;
  status: "pending_match" | "partially_fulfilled" | "fulfilled" | "expired" | "cancelled";
  isAiMatchPreferred: boolean;
  // Add any other fields relevant for matching by the AI
}

// Wrapper to include ID with data, useful when passing Firestore docs around
export interface FirestoreDocument<T> {
  id: string;
  data: T;
}

// Input for the Genkit AI flow
export interface MatchGenerationInput {
  // The item that triggered the flow (either a listing or a request)
  triggeringItem: FirestoreDocument<ProduceListingDocData | BuyerRequestDocData>;
  // The list of items to match against
  potentialMatches: Array<FirestoreDocument<ProduceListingDocData | BuyerRequestDocData>>;
  // Context to tell the flow how it was triggered
  context: "listing_triggered" | "request_triggered";
  // Optional configuration for the AI
  config?: {
    minScoreThreshold?: number; // e.g., 0.7
    // any other parameters to guide the AI
  };
}

// Output from the Genkit AI flow for a single suggested match
export interface GenkitMatchOutput {
  // If listing_triggered: listingId is triggeringItem.id, buyerRequestId is one of potentialMatches[].id
  // If request_triggered: buyerRequestId is triggeringItem.id, listingId is one of potentialMatches[].id
  listingId: string;
  farmerId: string; // From the listing involved in the match
  buyerRequestId: string;
  buyerId: string; // From the buyer request involved in the match
  suggestedOrderQuantity: number;
  suggestedOrderQuantityUnit: string;
  aiMatchScore: number; // Score from 0.0 to 1.0
  aiMatchRationale: string; // Textual explanation from AI
}

// Data to be stored in the MatchSuggestion document in Firestore
export interface MatchSuggestionFirestoreData {
  listingId: string;
  listingRefPath: string; // e.g., "produceListings/xyz"
  farmerId: string;
  buyerRequestId: string;
  buyerRequestRefPath: string; // e.g., "buyerRequests/abc"
  buyerId: string;
  suggestedOrderQuantity: number;
  suggestedOrderQuantityUnit: string;
  aiMatchScore: number;
  aiMatchRationale: string;
  status:
    | "pending_farmer_acceptance" // Farmer needs to accept/decline first
    | "pending_buyer_acceptance" // If farmer directly proposes to a specific buyer (future)
    | "accepted_by_farmer" // Farmer accepted, awaiting buyer
    | "accepted_by_buyer" // Buyer accepted, awaiting farmer
    | "order_proposed" // Both tentatively agree, an order document can now be created
    | "declined_by_farmer"
    | "declined_by_buyer"
    | "expired"; // Suggestion expired before action
  suggestionTimestamp: admin.firestore.FieldValue; // serverTimestamp()
  suggestionExpiryTimestamp: admin.firestore.Timestamp; // e.g., 24 hours from suggestionTimestamp
}
