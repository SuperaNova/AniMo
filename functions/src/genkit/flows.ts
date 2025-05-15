import {MatchGenerationInput, GenkitMatchOutput, ProduceListingDocData, BuyerRequestDocData, FirestoreDocument} from "../models/aiMatchingTypes";
import * as functions from "firebase-functions";

/**
 * MOCK IMPLEMENTATION of the Genkit flow for generating match suggestions.
 * Replace this with the actual Genkit flow import and call.
 *
 * @param {MatchGenerationInput} input The input containing the triggering item and potential matches.
 * @return {Promise<GenkitMatchOutput[]>} A promise that resolves to a list of match outputs.
 */
export async function generateMatchSuggestionsFlow(
  input: MatchGenerationInput
): Promise<GenkitMatchOutput[]> {
  functions.logger.info("[MOCK] generateMatchSuggestionsFlow called with input:", input);

  const suggestions: GenkitMatchOutput[] = [];
  const minScore = input.config?.minScoreThreshold || 0.0; // Use threshold if provided

  if (input.context === "listing_triggered") {
    const listing = input.triggeringItem as FirestoreDocument<ProduceListingDocData>;
    const potentialRequests = input.potentialMatches as Array<FirestoreDocument<BuyerRequestDocData>>;

    potentialRequests.forEach((request) => {
      // Mock logic: suggest a match if produce names are similar (very basic)
      if (listing.data.produceName.toLowerCase().includes(request.data.produceName.toLowerCase()) ||
          request.data.produceName.toLowerCase().includes(listing.data.produceName.toLowerCase())) {
        const score = Math.random() * (1.0 - 0.5) + 0.5; // Random score between 0.5 and 1.0
        if (score >= minScore) {
          suggestions.push({
            listingId: listing.id,
            farmerId: listing.data.farmerId,
            buyerRequestId: request.id,
            buyerId: request.data.buyerId,
            suggestedOrderQuantity: Math.min(listing.data.quantity, request.data.desiredQuantity),
            suggestedOrderQuantityUnit: listing.data.quantityUnit, // Assuming same unit for simplicity
            aiMatchScore: score,
            aiMatchRationale: `[MOCK] Good match: Produce name '${listing.data.produceName}' and '${request.data.produceName}' seem related. Listing quantity: ${listing.data.quantity}, Request quantity: ${request.data.desiredQuantity}.`,
          });
        }
      }
    });
  } else if (input.context === "request_triggered") {
    const request = input.triggeringItem as FirestoreDocument<BuyerRequestDocData>;
    const potentialListings = input.potentialMatches as Array<FirestoreDocument<ProduceListingDocData>>;

    potentialListings.forEach((listing) => {
      // Mock logic: suggest a match if produce names are similar
      if (listing.data.produceName.toLowerCase().includes(request.data.produceName.toLowerCase()) ||
          request.data.produceName.toLowerCase().includes(listing.data.produceName.toLowerCase())) {
        const score = Math.random() * (1.0 - 0.5) + 0.5; // Random score between 0.5 and 1.0
        if (score >= minScore) {
          suggestions.push({
            listingId: listing.id,
            farmerId: listing.data.farmerId,
            buyerRequestId: request.id,
            buyerId: request.data.buyerId,
            suggestedOrderQuantity: Math.min(listing.data.quantity, request.data.desiredQuantity),
            suggestedOrderQuantityUnit: request.data.desiredQuantityUnit, // Assuming same unit for simplicity
            aiMatchScore: score,
            aiMatchRationale: `[MOCK] Good match: Produce name '${request.data.produceName}' and '${listing.data.produceName}' seem related. Request quantity: ${request.data.desiredQuantity}, Listing quantity: ${listing.data.quantity}.`,
          });
        }
      }
    });
  }

  functions.logger.info("[MOCK] generateMatchSuggestionsFlow returning suggestions:", suggestions.length);
  return suggestions;
}
