import {
  MatchGenerationInputSchema,
  GenkitMatchOutputSchema,
  type MatchGenerationInput,
  type GenkitMatchOutput,
  type ProduceListingFirestoreDocument,
  type BuyerRequestFirestoreDocument,
  // Import your Zod schemas if you create them
  // MatchGenerationInputSchema,
  // GenkitMatchOutputSchema,
} from "../models/aiMatchingTypes";
import * as functions from "firebase-functions"; // For logger

// Using stubs instead of direct imports to work around TypeScript errors
import {defineFlow, generate, createRegistry} from "../genkitStub";
// Import only types from AI package
import type {ModelArgument} from "@genkit-ai/ai";

import {gemini15Flash} from "@genkit-ai/googleai"; // Model reference
import {z} from "zod"; // Restore Zod import for direct use

// Zod schemas are now imported from aiMatchingTypes.ts
// const MatchGenerationInputSchema = z.object({ ... });
// const GenkitMatchOutputSchema = z.object({ ... });

// Use console.log for maximum visibility in logs
console.log("Initializing flows.ts - setting up AI matching flow");

// Create registry explicitly here for better diagnostics
try {
  const registry = createRegistry();
  console.log("Registry created in flows.ts:", registry ? "success" : "failed");
} catch (err) {
  console.error("Error creating registry in flows.ts:", err);
}

// The core Genkit flow - using the simpler API approach without registry
export const generateMatchSuggestionsFlow = defineFlow(
  {
    name: "generateMatchSuggestionsFlow",
    inputSchema: MatchGenerationInputSchema, // Use imported Zod schema
    outputSchema: z.array(GenkitMatchOutputSchema), // Use imported Zod schema
  },
  async (input: MatchGenerationInput): Promise<GenkitMatchOutput[]> => {
    console.log("[Genkit] Flow function starting execution");
    
    functions.logger.info("[Genkit] generateMatchSuggestionsFlow called with input:", {
      context: input.context,
      // Ensure triggeringItem has an id. It will if it conforms to FirestoreDocumentSchema
      triggeringItemId: input.triggeringItem.id,
      potentialMatchesCount: input.potentialMatches.length,
      config: input.config,
    });

    const suggestions: GenkitMatchOutput[] = [];
    const minScoreThreshold = input.config?.minScoreThreshold || 0.7;

    const itemsToProcess: Array<{
      listing: ProduceListingFirestoreDocument; // Use Zod-inferred type
      request: BuyerRequestFirestoreDocument; // Use Zod-inferred type
    }> = [];

    if (input.context === "listing_triggered") {
      // Types are now more specific due to Zod schema in defineFlow
      const listing = input.triggeringItem as ProduceListingFirestoreDocument;
      const potentialRequests = input.potentialMatches as Array<BuyerRequestFirestoreDocument>;
      potentialRequests.forEach((request) => {
        itemsToProcess.push({listing, request});
      });
    } else if (input.context === "request_triggered") {
      const request = input.triggeringItem as BuyerRequestFirestoreDocument;
      const potentialListings = input.potentialMatches as Array<ProduceListingFirestoreDocument>;
      potentialListings.forEach((listing) => {
        itemsToProcess.push({listing, request});
      });
    }

    functions.logger.info(`[Genkit] Processing ${itemsToProcess.length} potential matches`);

    // Simple match logic without LLM for testing
    try {
      console.log("[Genkit] Testing simple match without LLM");
      
      // For debugging, try one simple fuzzy match without using LLM
      for (const itemPair of itemsToProcess) {
        const {listing, request} = itemPair;
        
        // Access data fields correctly via .data property, ensure these fields are in your Zod schemas
        if (!listing.data.produceName || !request.data.produceNeededName) {
          functions.logger.warn(
            `[Genkit] Skipping item pair due to missing produceName/produceNeededName. Listing: ${listing.id}, Request: ${request.id}`,
            {
              listingProduceName: listing.data.produceName,
              requestProduceNeededName: request.data.produceNeededName,
            }
          );
          continue;
        }
        
        // Try very simple fuzzy matching to test end-to-end functionality
        const listingName = (listing.data.produceName || "").toLowerCase();
        const requestName = (request.data.produceNeededName || "").toLowerCase();
        console.log(`Comparing listing "${listingName}" with request "${requestName}"`);
        
        // Simple fuzzy match - if one is a substring of the other
        if (listingName.includes(requestName) || requestName.includes(listingName)) {
          console.log(`Found fuzzy match between ${listingName} and ${requestName}`);
          
          // Check ids are present
          if (!listing.data.farmerId || !request.data.buyerId) {
            console.log(`Missing farmerId or buyerId - skipping match`);
            continue;
          }
          
          const aiMatchScore = 0.9; // High score for substring match
          suggestions.push({
            listingId: listing.id,
            farmerId: listing.data.farmerId as string,
            buyerRequestId: request.id,
            buyerId: request.data.buyerId as string,
            suggestedOrderQuantity: Math.min(
              listing.data.quantity || 0,
              request.data.quantity || 0
            ),
            suggestedOrderQuantityUnit: listing.data.unit || 
                                        request.data.unit || 
                                        "unit",
            aiMatchScore: aiMatchScore,
            aiMatchRationale: "Simple string match between produce names"
          });
          
          console.log(`Added match suggestion to results`);
        }
      }
    } catch (simpleMatchError) {
      console.error(`Error in simple matching:`, simpleMatchError);
    }
    
    if (suggestions.length > 0) {
      console.log(`[Genkit] Found ${suggestions.length} matches using simple string comparison`);
      functions.logger.info(
        `[Genkit] generateMatchSuggestionsFlow returning ${suggestions.length} suggestions from simple matching.`
      );
      return suggestions;
    }
    
    // If simple matching didn't work, try using LLM
    let usedLLM = false;
    
    for (const itemPair of itemsToProcess) {
      const {listing, request} = itemPair;

      // Access data fields correctly via .data property, ensure these fields are in your Zod schemas
      if (!listing.data.produceName || !request.data.produceNeededName) {
        continue; // Already logged warnings during simple matching
      }

      // Build a clear prompt for the LLM
      const prompt = `Considering a produce listing and a buyer request:
      Listing Produce Name: "${listing.data.produceName || ""}"
      Listing Category: "${listing.data.category || ""}" 
      Buyer Requested Produce Name: "${request.data.produceNeededName || ""}"
      Buyer Requested Category: "${request.data.category || ""}" 

      Do the "Listing Produce Name" and "Buyer Requested Produce Name" refer to essentially the same type of produce, considering their categories?
      Answer ONLY with "yes" or "no". Nothing else.`;

      try {
        // Log the intent to use LLM
        functions.logger.info(`[Genkit] Attempting LLM call for Listing ${listing.id}/Request ${request.id}`);
        console.log(`[Genkit] Attempting LLM call with prompt: ${prompt}`);
        
        // Add a timeout to the generate call
        const timeout = new Promise((_, reject) => 
          setTimeout(() => reject(new Error('LLM call timed out after 15 seconds')), 15000)
        );
        
        const llmResponsePromise = generate({
          model: gemini15Flash as ModelArgument, 
          prompt: prompt,
          config: {
            temperature: 0.1,
            maxOutputTokens: 10, // Slightly larger to handle potential errors
          },
        });
        
        // Race the API call against the timeout
        const llmResponse = await Promise.race([llmResponsePromise, timeout]);
        usedLLM = true;

        // Log the raw response for debugging
        console.log(`[Genkit] Raw LLM response:`, JSON.stringify(llmResponse));
        functions.logger.info(`[Genkit] Raw LLM response:`, JSON.stringify(llmResponse));
        
        // Safe access to text property with fallback
        const responseText = llmResponse?.text?.trim?.().toLowerCase?.() || "";
        
        functions.logger.info(
          `[Genkit] LLM response for Listing ${listing.id}/Request ${request.id}: '${responseText}'`
        );
        
        let aiMatchScore = 0.1;
        let aiMatchRationale = "LLM indicated no match or unclear response.";

        // Exact matching for expected responses only
        if (responseText === "yes") {
          aiMatchScore = 0.9;
          aiMatchRationale = "LLM confirmed produce names and categories are a good match.";
        } else if (responseText === "no") {
          aiMatchScore = 0.1;
          aiMatchRationale = "LLM indicated produce names/categories are not a match.";
        } else if (responseText.includes("stub_response")) {
          functions.logger.error(`[Genkit] Using stub response - API call likely failed`);
          aiMatchRationale = "Error: API call returned stub response";
        } else if (responseText.includes("error:")) {
          functions.logger.error(`[Genkit] Error in API call: ${responseText}`);
          aiMatchRationale = `Error: ${responseText}`;
        } else {
          functions.logger.warn(
            `[Genkit] Unexpected LLM response for Listing ${listing.id}/Request ${request.id}: '${responseText}'`
          );
        }

        // Only add suggestions that meet the threshold
        if (aiMatchScore >= minScoreThreshold) {
          // Ensure farmerId and buyerId are present
          if (!listing.data.farmerId || !request.data.buyerId) {
            functions.logger.error(
              `[Genkit] Missing farmerId or buyerId. Listing: ${listing.id}, Request: ${request.id}`,
              {
                farmerId: listing.data.farmerId,
                buyerId: request.data.buyerId,
              }
            );
            continue;
          }

          // Default values for quantities and units to avoid undefined
          const suggestedQuantity = Math.min(
            (listing.data.quantity || 0),
            (request.data.quantity || 0)
          );
          
          const suggestedUnit = listing.data.unit || 
                                request.data.unit || 
                                "unit"; // Fallback value
          
          suggestions.push({
            listingId: listing.id,
            farmerId: listing.data.farmerId as string,
            buyerRequestId: request.id,
            buyerId: request.data.buyerId as string,
            suggestedOrderQuantity: suggestedQuantity,
            suggestedOrderQuantityUnit: suggestedUnit,
            aiMatchScore: aiMatchScore,
            aiMatchRationale: aiMatchRationale,
          });
        }
      } catch (error) {
        console.error(`[Genkit] Error calling LLM:`, error);
        functions.logger.error(
          `[Genkit] Error calling LLM for Listing ${listing.id}/Request ${request.id}:`,
          error
        );
      }
    }

    const methodUsed = usedLLM ? "LLM" : "no LLM calls made";
    console.log(`[Genkit] Flow completed using ${methodUsed}`);
    
    functions.logger.info(
      `[Genkit] generateMatchSuggestionsFlow returning ${suggestions.length} suggestions.`
    );
    return suggestions;
  }
);
