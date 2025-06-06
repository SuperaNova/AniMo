import * as functions from "firebase-functions";
import { admin, db } from "../admin"; // Import initialized admin and db instances
import {Timestamp, FieldValue} from "firebase-admin/firestore"; // Import Timestamp and FieldValue
import {z} from "zod"; // Import Zod

import {generateMatchSuggestionsFlow} from "../genkit/flows"; 
import {onDocumentCreated} from "firebase-functions/v2/firestore";
export const LocationDataSchema = z.object({
  address: z.string().optional(),
  geoPoint: z.custom<admin.firestore.GeoPoint>((val: unknown) => val instanceof admin.firestore.GeoPoint).optional(),
  city: z.string().optional(),
  region: z.string().optional(),
  country: z.string().optional(),
  postalCode: z.string().optional(),
});
export type LocationData = z.infer<typeof LocationDataSchema>;

// Zod schema for ProduceListingDocData (example, expand as needed based on project overview)
export const ProduceListingDocDataSchema = z.object({
  sellerId: z.string(),
  category: z.string(),
  variety: z.string().optional(),
  quantity: z.number(),
  unit: z.string(),
  pricePerUnit: z.number().optional(),
  description: z.string().optional(),
  location: LocationDataSchema,
  mediaUrls: z.array(z.string()).optional(),
  status: z.enum(["available", "partially_committed", "committed", "unavailable", "expired"]),
  isAiMatchPreferred: z.boolean().optional(),
  creationTimestamp: z.custom<Timestamp>((val: unknown) => val instanceof Timestamp),
  expiryTimestamp: z.custom<Timestamp>((val: unknown) => val instanceof Timestamp).optional(),
  lastUpdateTimestamp: z.custom<Timestamp>((val: unknown) => val instanceof Timestamp),
  // Add other fields from your project overview
  produceName: z.string().optional(), // Added as it's used in flows.ts
  farmerId: z.string().optional(), // Added as it's used in flows.ts
  quantityUnit: z.string().optional(), // Added based on flows.ts usage
});
export type ProduceListingDocData = z.infer<typeof ProduceListingDocDataSchema>;

// Zod schema for BuyerRequestDocData (example, expand as needed)
export const BuyerRequestDocDataSchema = z.object({
  buyerId: z.string(),
  category: z.string().optional(),
  variety: z.string().optional(),
  quantity: z.number().optional(),
  unit: z.string().optional(),
  targetPricePerUnit: z.number().optional(),
  description: z.string().optional(),
  deliveryLocation: LocationDataSchema,
  status: z.enum(["pending_match", "partially_fulfilled", "fulfilled", "cancelled", "expired"]),
  isAiMatchPreferred: z.boolean().optional(),
  creationTimestamp: z.custom<Timestamp>((val) => val instanceof Timestamp).optional(),
  expiryTimestamp: z.custom<Timestamp>((val) => val instanceof Timestamp).optional(),
  lastUpdateTimestamp: z.custom<Timestamp>((val) => val instanceof Timestamp).optional(),
  // Add Dart model field names
  produceNeededName: z.string().optional(),
  produceNeededCategory: z.string().optional(),
  quantityNeeded: z.number().optional(),
  quantityUnit: z.string().optional(),
  requestDateTime: z.custom<Timestamp>((val) => val instanceof Timestamp).optional(),
  deliveryDeadline: z.custom<Timestamp>((val) => val instanceof Timestamp).optional(),
  lastUpdated: z.custom<Timestamp>((val) => val instanceof Timestamp).optional(),
  priceRangeMinPerUnit: z.number().optional(),
  priceRangeMaxPerUnit: z.number().optional(),
  // Other possible fields
  produceCategory: z.string().optional(),
  desiredQuantity: z.number().optional(),
});
export type BuyerRequestDocData = z.infer<typeof BuyerRequestDocDataSchema>;

// Generic FirestoreDocument Zod Schema - Using lowercase function name for ESLint
export const createFirestoreDocumentSchema = <T extends z.ZodTypeAny>(dataSchema: T) =>
  z.object({
    id: z.string(),
    data: dataSchema,
  });

// Generic FirestoreDocument type - Modified to work with both Zod and non-Zod types
export type FirestoreDocument<T> = {
  id: string;
  data: T;
};

// Specific Firestore document types using the schema
export const ProduceListingFirestoreDocumentSchema = createFirestoreDocumentSchema(ProduceListingDocDataSchema);
export type ProduceListingFirestoreDocument = z.infer<typeof ProduceListingFirestoreDocumentSchema>;

export const BuyerRequestFirestoreDocumentSchema = createFirestoreDocumentSchema(BuyerRequestDocDataSchema);
export type BuyerRequestFirestoreDocument = z.infer<typeof BuyerRequestFirestoreDocumentSchema>;

// Zod schema for MatchGenerationInput
export const MatchGenerationInputSchema = z.object({
  triggeringItem: z.union([ProduceListingFirestoreDocumentSchema, BuyerRequestFirestoreDocumentSchema]),
  potentialMatches: z.array(z.union([ProduceListingFirestoreDocumentSchema, BuyerRequestFirestoreDocumentSchema])),
  context: z.enum(["listing_triggered", "request_triggered"]),
  config: z.object({minScoreThreshold: z.number().optional()}).optional(),
});
export type MatchGenerationInput = z.infer<typeof MatchGenerationInputSchema>;

// Zod schema for GenkitMatchOutput (as used in flows.ts)
export const GenkitMatchOutputSchema = z.object({
  listingId: z.string(),
  farmerId: z.string(), // Ensure this exists in ProduceListingDocDataSchema
  buyerRequestId: z.string(), // Changed from optional to required
  buyerId: z.string(), // Ensure this exists in BuyerRequestDocDataSchema
  suggestedOrderQuantity: z.number(),
  suggestedOrderQuantityUnit: z.string(),
  aiMatchScore: z.number(),
  aiMatchRationale: z.string(),
});
export type GenkitMatchOutput = z.infer<typeof GenkitMatchOutputSchema>;

// Custom validation function for server timestamps that uses lowercase naming to avoid ESLint new-cap error
const isTimestampOrFieldValue = (val: unknown): boolean => {
  return val instanceof Timestamp ||
    (typeof val === "object" && val !== null && "_methodName" in val &&
    ((val as Record<string, unknown>)._methodName === "FieldValue.serverTimestamp" ||
     (val as {constructor: {name: string}}).constructor.name === "FieldValue"));
};

// Corrected schema definition that uses the lowercase function for validation
export const MatchSuggestionFirestoreDataSchema = z.object({
  listingId: z.string(),
  listingRefPath: z.string(),
  farmerId: z.string(),
  buyerRequestId: z.string(), // Already required, matches GenkitMatchOutputSchema now
  buyerRequestRefPath: z.string(),
  buyerId: z.string(),
  suggestedOrderQuantity: z.number(),
  suggestedOrderQuantityUnit: z.string(),
  aiMatchScore: z.number(),
  aiMatchRationale: z.string(),
  status: z.enum([
    "ai_suggestion_for_farmer",
    "ai_suggestion_for_buyer",
    "accepted_by_farmer",
    "accepted_by_buyer",
    "declined_by_farmer",
    "declined_by_buyer",
    "expired",
    "order_created",
    "order_processing",
  ]),
  suggestionTimestamp: z.custom<Timestamp | FieldValue>(isTimestampOrFieldValue),
  suggestionExpiryTimestamp: z.custom<Timestamp>((val: unknown) => val instanceof Timestamp),
  // Add any other fields like 'version', 'updatedBy', etc.
});
export type MatchSuggestionFirestoreData = z.infer<typeof MatchSuggestionFirestoreDataSchema>;

/**
 * Processes a new produce listing and finds potential buyer request matches
 * @param {ProduceListingFirestoreDocument} listingDoc The new produce listing document
 * @return {Promise<void>} A promise that resolves when processing is complete
 */
async function prepareAndRunFlowForListing(
  listingDoc: ProduceListingFirestoreDocument // Now uses Zod-inferred type
): Promise<void> {
  functions.logger.info(`[handleAiMatching] Processing new listing: ${listingDoc.id}`);

  const requestsSnapshot = await db.collection("buyerRequests")
    .where("status", "in", ["pending_match", "partially_fulfilled"])
    .get();

  if (requestsSnapshot.empty) {
    functions.logger.info("[handleAiMatching] No active buyer requests found for listing.", {listingId: listingDoc.id});
    return;
  }

  const potentialMatches: BuyerRequestFirestoreDocument[] = requestsSnapshot.docs.map((doc) => ({
    id: doc.id,
    // Ensure data conforms to BuyerRequestDocDataSchema; consider parsing for safety
    data: BuyerRequestDocDataSchema.parse(doc.data()), // Or .safeParse() for error handling
  }));

  const flowInput: MatchGenerationInput = { // Type is z.infer<typeof MatchGenerationInputSchema>
    triggeringItem: listingDoc,
    potentialMatches: potentialMatches,
    context: "listing_triggered",
    config: {minScoreThreshold: 0.7},
  };

  try {
    // Directly call the flow function
    const suggestions: GenkitMatchOutput[] = await generateMatchSuggestionsFlow(flowInput);
    functions.logger.info(`[handleAiMatching] Received ${suggestions.length} suggestions for listing ${listingDoc.id}`);

    for (const suggestion of suggestions) { // suggestion is GenkitMatchOutput
      const matchSuggestionData = MatchSuggestionFirestoreDataSchema.parse({
        ...suggestion, // Spread fields from GenkitMatchOutput
        listingRefPath: `produceListings/${suggestion.listingId}`,
        buyerRequestRefPath: `buyerRequests/${suggestion.buyerRequestId}`, // Ensure buyerRequestId is present if not optional
        status: "ai_suggestion_for_farmer",
        suggestionTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        suggestionExpiryTimestamp: admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
      });
      await db.collection("matchSuggestions").add(matchSuggestionData);
      functions.logger.info(`[handleAiMatching] Created MatchSuggestion for Listing ${suggestion.listingId} and Request ${suggestion.buyerRequestId}`);
    }
  } catch (error) {
    functions.logger.error("[handleAiMatching] Error running AI flow for listing", {
      listingId: listingDoc.id,
      error,
    });
  }
}

/**
 * Processes a new buyer request and finds potential produce listing matches
 * @param {BuyerRequestFirestoreDocument} requestDoc The new buyer request document
 * @return {Promise<void>} A promise that resolves when processing is complete
 */
async function prepareAndRunFlowForRequest(
  requestDoc: BuyerRequestFirestoreDocument // Zod-inferred type
): Promise<void> {
  functions.logger.info(`[handleAiMatching] Processing new request: ${requestDoc.id}`);

  if (!requestDoc.data.isAiMatchPreferred) {
    functions.logger.info("[handleAiMatching] Request does not want AI matching", {requestId: requestDoc.id});
    return;
  }

  const listingsSnapshot = await db.collection("produceListings")
    .where("status", "in", ["available", "partially_committed"])
    .get();

  if (listingsSnapshot.empty) {
    functions.logger.info("[handleAiMatching] No active listings found for request", {requestId: requestDoc.id});
    return;
  }

  const potentialMatches: ProduceListingFirestoreDocument[] = listingsSnapshot.docs.map((doc) => ({
    id: doc.id,
    // Ensure data conforms to ProduceListingDocDataSchema with parsing
    data: ProduceListingDocDataSchema.parse(doc.data()),
  }));

  const flowInput: MatchGenerationInput = {
    triggeringItem: requestDoc,
    potentialMatches: potentialMatches,
    context: "request_triggered",
    config: {minScoreThreshold: 0.7},
  };

  try {
    // Directly call the flow function
    const suggestions: GenkitMatchOutput[] = await generateMatchSuggestionsFlow(flowInput);
    functions.logger.info(`[handleAiMatching] Received ${suggestions.length} suggestions for request ${requestDoc.id}`);

    for (const suggestion of suggestions) {
      const matchSuggestionData = MatchSuggestionFirestoreDataSchema.parse({
        ...suggestion,
        listingRefPath: `produceListings/${suggestion.listingId}`,
        buyerRequestRefPath: `buyerRequests/${suggestion.buyerRequestId}`, // Ensure buyerRequestId is present
        status: "ai_suggestion_for_buyer",
        suggestionTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        suggestionExpiryTimestamp: admin.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
      });
      await db.collection("matchSuggestions").add(matchSuggestionData);
      functions.logger.info(`[handleAiMatching] Created MatchSuggestion for Listing ${suggestion.listingId} and Request ${suggestion.buyerRequestId}`);
    }
  } catch (error) {
    functions.logger.error("[handleAiMatching] Error running AI flow for request", {
      requestId: requestDoc.id,
      error,
    });
  }
}

export const onNewProduceListingForAiMatching = onDocumentCreated("produceListings/{listingId}", async (event) => {
  const listingId = event.params.listingId;
  const snapshot = event.data;
  if (!snapshot) {
    functions.logger.error("New produce listing event has no data object", {listingId});
    return;
  }
  // Validate snapshot data with Zod
  const parseResult = ProduceListingDocDataSchema.safeParse(snapshot.data());
  if (!parseResult.success) {
    functions.logger.error("New produce listing data validation failed", {listingId, errors: parseResult.error.issues});
    return;
  }
  const listingData = parseResult.data;

  const listingDoc: ProduceListingFirestoreDocument = {
    id: listingId,
    data: listingData,
  };
  await prepareAndRunFlowForListing(listingDoc);
});

export const onNewBuyerRequestForAiMatching = onDocumentCreated("buyerRequests/{requestId}", async (event) => {
  const requestId = event.params.requestId;
  const snapshot = event.data;
  if (!snapshot) {
    functions.logger.error("New buyer request event has no data object", {requestId});
    return;
  }
  // Validate snapshot data with Zod
  const parseResult = BuyerRequestDocDataSchema.safeParse(snapshot.data());
  if (!parseResult.success) {
    functions.logger.error("New buyer request data validation failed", {requestId, errors: parseResult.error.issues});
    return;
  }
  const requestData = parseResult.data;

  if (!requestData.isAiMatchPreferred) {
    functions.logger.info("New buyer request not processed for AI matching.", {
      requestId,
      isAiMatchPreferred: requestData.isAiMatchPreferred,
    });
    return;
  }

  const requestDoc: BuyerRequestFirestoreDocument = {
    id: requestId,
    data: requestData,
  };

  await prepareAndRunFlowForRequest(requestDoc);
});
