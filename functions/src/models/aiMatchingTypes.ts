import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Timestamp, FieldValue} from "firebase-admin/firestore"; // Import Timestamp and FieldValue
import {z} from "zod"; // Import Zod

// Import our stub instead of direct import
import {run} from "../genkitStub";
import {generateMatchSuggestionsFlow} from "../genkit/flows"; // This might error if flows.ts has issues
import {onDocumentCreated} from "firebase-functions/v2/firestore";
// Removed: import { QueryDocumentSnapshot } from "firebase-admin/firestore"; // No longer explicitly used
// Removed: import { MatchSuggestionFirestoreDataSchema } from "./zodSchemas"; // Will define schemas here

const db = admin.firestore();

// Zod schema for LocationData (example, expand as needed)
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
  category: z.string(),
  variety: z.string().optional(),
  quantity: z.number(),
  unit: z.string(),
  targetPricePerUnit: z.number().optional(),
  description: z.string().optional(),
  deliveryLocation: LocationDataSchema,
  status: z.enum(["pending_match", "partially_fulfilled", "fulfilled", "cancelled", "expired"]),
  isAiMatchPreferred: z.boolean().optional(),
  creationTimestamp: z.custom<Timestamp>((val) => val instanceof Timestamp),
  expiryTimestamp: z.custom<Timestamp>((val) => val instanceof Timestamp).optional(),
  lastUpdateTimestamp: z.custom<Timestamp>((val) => val instanceof Timestamp),
  // Add other fields from your project overview
  produceNeededName: z.string().optional(), // Added as it's used in flows.ts
  produceCategory: z.string().optional(), // Added based on flows.ts usage (ensure it's distinct from 'category' if needed)
  desiredQuantity: z.number().optional(), // Added based on flows.ts usage
  quantityUnit: z.string().optional(), // Added based on flows.ts usage
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

// Removed old interface exports as they are now types inferred from Zod schemas
// export interface ProduceListingDocData { ... }
// export interface BuyerRequestDocData { ... }
// export interface MatchGenerationInput { ... }
// export interface ProduceListingFirestoreDocument { ... }
// export interface BuyerRequestFirestoreDocument { ... }
// export interface LocationData { ... }

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
    // Use the simple signature for run without registry
    const suggestions: GenkitMatchOutput[] = await run(
      "generateMatchSuggestions", // Flow name as string
      flowInput, // Flow input
      generateMatchSuggestionsFlow // The flow function
    );
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
    functions.logger.error(`[handleAiMatching] Error running Genkit flow for listing ${listingDoc.id}:`, error);
    if (error instanceof z.ZodError) {
      functions.logger.error("[handleAiMatching] Zod validation error:", error.issues);
    }
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

  functions.logger.info(`[handleAiMatching] Processing new buyer request: ${requestDoc.id}`);

  const listingsSnapshot = await db.collection("produceListings")
    .where("status", "in", ["available", "partially_committed"])
    .get();

  if (listingsSnapshot.empty) {
    functions.logger.info("[handleAiMatching] No active produce listings found for buyer request.", {requestId: requestDoc.id});
    return;
  }

  const potentialMatches: ProduceListingFirestoreDocument[] = listingsSnapshot.docs.map((doc) => {
    // Validate each potential match; skip or log error if invalid
    const parsedData = ProduceListingDocDataSchema.parse(doc.data()); // or .safeParse()
    return {
      id: doc.id,
      data: parsedData,
    };
  });

  const flowInput: MatchGenerationInput = {
    triggeringItem: requestDoc,
    potentialMatches: potentialMatches,
    context: "request_triggered",
    config: {minScoreThreshold: 0.7},
  };

  try {
    // Use the simple signature for run without registry
    const suggestions: GenkitMatchOutput[] = await run(
      "generateMatchSuggestions", // Flow name as string
      flowInput, // Flow input
      generateMatchSuggestionsFlow // The flow function
    );
    functions.logger.info(`[handleAiMatching] Received ${suggestions.length} suggestions for buyer request ${requestDoc.id}`);

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
    functions.logger.error(`[handleAiMatching] Error running Genkit flow for buyer request ${requestDoc.id}:`, error);
    if (error instanceof z.ZodError) {
      functions.logger.error("[handleAiMatching] Zod validation error:", error.issues);
    }
  }
});
