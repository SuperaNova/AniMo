import {onDocumentCreated, FirestoreEvent} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { admin, db } from "../admin"; // Import initialized admin and db
import {REGION} from "../config";
import {
  ProduceListingDocData,
  BuyerRequestDocData,
  MatchGenerationInput,
  GenkitMatchOutput,
  MatchSuggestionFirestoreData,
  FirestoreDocument,
} from "../models/aiMatchingTypes";
import {generateMatchSuggestionsFlow} from "../genkit/flows"; // Mock flow

// No need to initialize Firestore here since we're importing it
// const db = admin.firestore();
const MIN_AI_SCORE_THRESHOLD = 0.7; // Default minimum score to create a suggestion
const SUGGESTION_TTL_HOURS = 24; // Suggestions expire after 24 hours

export const onNewProduceListingForAiMatching = onDocumentCreated(
  {
    document: "produceListings/{listingId}",
    region: REGION,
  },
  async (event: FirestoreEvent<admin.firestore.QueryDocumentSnapshot | undefined>) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error("No data associated with the event for onNewProduceListingForAiMatching");
      return null;
    }
    const listingId = event.params.listingId;
    const listingData = snapshot.data() as ProduceListingDocData;

    // Ensure listingData is not undefined (though .data() on a QueryDocumentSnapshot should be defined)
    if (!listingData) {
      logger.error(`Listing data for ${listingId} is undefined. This should not happen for onCreate.`);
      return null;
    }
    const triggeringItem: FirestoreDocument<ProduceListingDocData> = {id: listingId, data: listingData};

    logger.info(`New produce listing ${listingId} by farmer ${listingData.farmerId}, triggering AI matching.`);

    // 1. Fetch active buyer requests
    const buyerRequestsQuery = db.collection("buyerRequests")
      .where("status", "==", "pending_match");
      // Removed the date comparison to avoid requiring an index
      // We will filter in memory instead

    const buyerRequestsSnapshot = await buyerRequestsQuery.get();

    if (buyerRequestsSnapshot.empty) {
      logger.info(`No active buyer requests found for listing ${listingId}.`);
      return null;
    }

    // Filter buyer requests by delivery deadline in memory to avoid requiring an index
    const currentTimestamp = admin.firestore.Timestamp.now();
    const potentialMatches: Array<FirestoreDocument<BuyerRequestDocData>> = buyerRequestsSnapshot.docs
      .filter(doc => {
        const data = doc.data();
        return (data.deliveryDeadline && data.deliveryDeadline > currentTimestamp) ||
               (data.expiryTimestamp && data.expiryTimestamp > currentTimestamp);
      })
      .map((doc) => ({
        id: doc.id,
        data: doc.data() as BuyerRequestDocData,
      }));

    logger.info(`Found ${potentialMatches.length} potential buyer requests for listing ${listingId}.`);

    // Ensure listing has produceName field to avoid LLM errors
    if (!listingData.produceName) {
      logger.warn(`Listing ${listingId} is missing produceName field, adding a default value`);
      (listingData as any).produceName = "Unlabeled Produce";
    }

    // Ensure all potential matches have the required fields
    const validPotentialMatches = potentialMatches.filter(match => {
      if (!match.data.produceNeededName) {
        logger.warn(`Request ${match.id} is missing produceNeededName field, it will be excluded from matching`);
        return false;
      }
      return true;
    });
    
    if (validPotentialMatches.length === 0) {
      logger.info(`No valid buyer requests found for listing ${listingId} after filtering.`);
      return null;
    }

    // 2. Prepare input for Genkit flow
    const genkitInput: MatchGenerationInput = {
      triggeringItem: triggeringItem,
      potentialMatches: validPotentialMatches,
      context: "listing_triggered",
      config: {
        minScoreThreshold: MIN_AI_SCORE_THRESHOLD,
      },
    };

    // 3. Call Genkit flow (mocked)
    let matchOutputs: GenkitMatchOutput[] = [];
    try {
      matchOutputs = await generateMatchSuggestionsFlow(genkitInput);
    } catch (error) {
      logger.error(`Error calling Genkit flow for listing ${listingId}:`, error);
      return null;
    }

    if (!matchOutputs || matchOutputs.length === 0) {
      logger.info(`Genkit flow returned no matches for listing ${listingId}.`);
      return null;
    }

    logger.info(`Genkit flow returned ${matchOutputs.length} matches for listing ${listingId}.`);

    // 4. Process Genkit results and create MatchSuggestion documents
    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();
    const expiryDate = new Date(now.toDate().getTime() + SUGGESTION_TTL_HOURS * 60 * 60 * 1000);
    const suggestionExpiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

    matchOutputs.forEach((output) => {
      if (output.aiMatchScore >= (genkitInput.config?.minScoreThreshold || MIN_AI_SCORE_THRESHOLD)) {
        const suggestionRef = db.collection("matchSuggestions").doc(); // Auto-generate ID
        const suggestionData: MatchSuggestionFirestoreData = {
          listingId: output.listingId,
          listingRefPath: db.collection("produceListings").doc(output.listingId).path,
          farmerId: output.farmerId,
          buyerRequestId: output.buyerRequestId,
          buyerRequestRefPath: db.collection("buyerRequests").doc(output.buyerRequestId).path,
          buyerId: output.buyerId,
          suggestedOrderQuantity: output.suggestedOrderQuantity,
          suggestedOrderQuantityUnit: output.suggestedOrderQuantityUnit,
          aiMatchScore: output.aiMatchScore,
          aiMatchRationale: output.aiMatchRationale,
          status: "ai_suggestion_for_farmer",
          suggestionTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          suggestionExpiryTimestamp: suggestionExpiryTimestamp,
        };
        batch.set(suggestionRef, suggestionData);
        logger.info(`Creating MatchSuggestion ${suggestionRef.id} (ai_suggestion_for_farmer) for new listing ${output.listingId} and existing request ${output.buyerRequestId}.`);
      }
    });

    try {
      await batch.commit();
      logger.info(`Successfully created ${matchOutputs.filter((o) => o.aiMatchScore >= (genkitInput.config?.minScoreThreshold || MIN_AI_SCORE_THRESHOLD)).length} match suggestions for listing ${listingId}.`);
    } catch (error) {
      logger.error(`Error committing batch for match suggestions (listing ${listingId}):`, error);
    }
    return null;
  });

export const onNewBuyerRequestForAiMatching = onDocumentCreated(
  {
    document: "buyerRequests/{requestId}",
    region: REGION,
  },
  async (event: FirestoreEvent<admin.firestore.QueryDocumentSnapshot | undefined>) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error("No data associated with the event for onNewBuyerRequestForAiMatching");
      return null;
    }
    const requestId = event.params.requestId;
    const requestData = snapshot.data() as BuyerRequestDocData;

    // Add detailed logging to help diagnose the issue
    logger.info(`[DEBUGGING] Received new buyer request with ID: ${requestId}`);
    logger.info(`[DEBUGGING] Document data:`, JSON.stringify({
      fields: Object.keys(requestData),
      isAiMatchPreferred: requestData.isAiMatchPreferred,
      status: requestData.status,
      buyerId: requestData.buyerId,
      produceNeededName: requestData.produceNeededName,
      deliveryDeadline: requestData.deliveryDeadline,
      expiryTimestamp: requestData.expiryTimestamp,
    }));

    if (!requestData) {
      logger.error(`Request data for ${requestId} is undefined. This should not happen for onCreate.`);
      return null;
    }
    const triggeringItem: FirestoreDocument<BuyerRequestDocData> = {id: requestId, data: requestData};

    if (!requestData.isAiMatchPreferred) {
      logger.info(`Buyer request ${requestId} does not prefer AI matching. Skipping.`);
      return null;
    }

    logger.info(`New buyer request ${requestId} by buyer ${requestData.buyerId} prefers AI matching, triggering.`);

    // 1. Fetch active produce listings
    const produceListingsQuery = db.collection("produceListings")
      .where("status", "==", "available");
      // Removed the date comparison to avoid requiring an index
      // We will filter in memory instead

    const listingsSnapshot = await produceListingsQuery.get();

    if (listingsSnapshot.empty) {
      logger.info(`No active produce listings found for buyer request ${requestId}.`);
      return null;
    }

    // Filter listings by expiry date in memory to avoid requiring an index
    const currentTime = admin.firestore.Timestamp.now();
    const potentialMatches: Array<FirestoreDocument<ProduceListingDocData>> = listingsSnapshot.docs
      .filter(doc => {
        const data = doc.data();
        return (data.expiryTimestamp && data.expiryTimestamp > currentTime) || 
               (data.deliveryDeadline && data.deliveryDeadline > currentTime);
      })
      .map((doc) => ({
        id: doc.id,
        data: doc.data() as ProduceListingDocData,
      }));

    logger.info(`Found ${potentialMatches.length} potential produce listings for request ${requestId}.`);

    // Ensure request has produceNeededName field to avoid LLM errors
    if (!requestData.produceNeededName) {
      logger.warn(`Request ${requestId} is missing produceNeededName field, adding a default value`);
      (requestData as any).produceNeededName = "Unspecified Produce";
    }

    // Ensure all potential matches have the required fields
    const validPotentialMatches = potentialMatches.filter(match => {
      if (!match.data.produceName) {
        logger.warn(`Listing ${match.id} is missing produceName field, it will be excluded from matching`);
        return false;
      }
      return true;
    });
    
    if (validPotentialMatches.length === 0) {
      logger.info(`No valid produce listings found for request ${requestId} after filtering.`);
      return null;
    }

    // 2. Prepare input for Genkit flow
    const genkitInput: MatchGenerationInput = {
      triggeringItem: triggeringItem,
      potentialMatches: validPotentialMatches,
      context: "request_triggered",
      config: {
        minScoreThreshold: MIN_AI_SCORE_THRESHOLD,
      },
    };

    // 3. Call Genkit flow (mocked)
    let matchOutputs: GenkitMatchOutput[] = [];
    try {
      matchOutputs = await generateMatchSuggestionsFlow(genkitInput);
    } catch (error) {
      logger.error(`Error calling Genkit flow for request ${requestId}:`, error);
      return null;
    }

    if (!matchOutputs || matchOutputs.length === 0) {
      logger.info(`Genkit flow returned no matches for request ${requestId}.`);
      return null;
    }
    logger.info(`Genkit flow returned ${matchOutputs.length} matches for request ${requestId}.`);

    // --- Sort matches by score (descending) and take top N (e.g., 3) ---
    const sortedMatches = matchOutputs.sort((a, b) => b.aiMatchScore - a.aiMatchScore);
    const TOP_N_SUGGESTIONS = 3;
    const selectedMatches = sortedMatches.slice(0, TOP_N_SUGGESTIONS);

    logger.info(`Selected top ${selectedMatches.length} matches for request ${requestId} based on score.`);

    // 4. Process selected Genkit results and create MatchSuggestion documents
    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();
    const expiryDate = new Date(now.toDate().getTime() + SUGGESTION_TTL_HOURS * 60 * 60 * 1000);
    const suggestionExpiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);

    selectedMatches.forEach((output) => {
      if (output.aiMatchScore >= (genkitInput.config?.minScoreThreshold || MIN_AI_SCORE_THRESHOLD)) {
        const suggestionRef = db.collection("matchSuggestions").doc(); // Auto-generate ID
        const suggestionData: MatchSuggestionFirestoreData = {
          listingId: output.listingId,
          listingRefPath: db.collection("produceListings").doc(output.listingId).path,
          farmerId: output.farmerId,
          buyerRequestId: output.buyerRequestId,
          buyerRequestRefPath: db.collection("buyerRequests").doc(output.buyerRequestId).path,
          buyerId: output.buyerId,
          suggestedOrderQuantity: output.suggestedOrderQuantity,
          suggestedOrderQuantityUnit: output.suggestedOrderQuantityUnit,
          aiMatchScore: output.aiMatchScore,
          aiMatchRationale: output.aiMatchRationale,
          status: "ai_suggestion_for_buyer",
          suggestionTimestamp: admin.firestore.FieldValue.serverTimestamp(),
          suggestionExpiryTimestamp: suggestionExpiryTimestamp,
        };
        batch.set(suggestionRef, suggestionData);
        logger.info(`Creating MatchSuggestion ${suggestionRef.id} (ai_suggestion_for_buyer) for new request ${output.buyerRequestId} and existing listing ${output.listingId}.`);
      }
    });

    try {
      await batch.commit();
      logger.info(`Successfully created ${selectedMatches.filter((o) => o.aiMatchScore >= (genkitInput.config?.minScoreThreshold || MIN_AI_SCORE_THRESHOLD)).length} match suggestions for request ${requestId}.`);
    } catch (error) {
      logger.error(`Error committing batch for match suggestions (request ${requestId}):`, error);
    }
    return null;
  });
