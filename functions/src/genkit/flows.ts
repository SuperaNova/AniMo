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
// @ts-ignore - Ignoring module resolution for firebase-functions
import * as functions from "firebase-functions"; // For logger

// Using stubs instead of direct imports to work around TypeScript errors
import {defineFlow, generate, createRegistry} from "../genkitStub";
// Import only types from AI package
// @ts-ignore - Ignoring module resolution for @genkit-ai/ai
import type {ModelArgument} from "@genkit-ai/ai";

// @ts-ignore - Ignoring module resolution for @genkit-ai/googleai
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

// Zod schema for LLM response parsing
const LLMMatchResponseSchema = z.object({
  score: z.number().min(1).max(10),
  rationale: z.string(),
});
type LLMMatchResponse = z.infer<typeof LLMMatchResponseSchema>;

// Helper function to check if an object has a toDate method
function hasToDateMethod(obj: any): obj is { toDate(): Date } {
  return obj && typeof obj === 'object' && typeof obj.toDate === 'function';
}

// Helper to calculate days until expiry
function calculateDaysUntil(timestamp: any): number {
  if (!hasToDateMethod(timestamp)) return 999; // Default if no timestamp or invalid format
  
  const expiryDate = timestamp.toDate();
  const currentDate = new Date();
  
  // Calculate difference in days
  const diffTime = expiryDate.getTime() - currentDate.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  
  return diffDays > 0 ? diffDays : 0; // Return 0 if already expired
}

// Type guard for location data
function hasLocationData(obj: any): obj is { city?: string; region?: string } {
  return obj && typeof obj === 'object';
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
      triggeringItemId: input.triggeringItem.id,
      potentialMatchesCount: input.potentialMatches.length,
      config: input.config,
    });

    const suggestions: GenkitMatchOutput[] = [];
    const minScoreThreshold = input.config?.minScoreThreshold || 0.7;
    const currentDate = new Date();
    
    // Log the current configuration
    console.log(`[Genkit] Using minScoreThreshold: ${minScoreThreshold}`);
    console.log(`[Genkit] Current date: ${currentDate.toISOString()}`);
    console.log(`[Genkit] Using LLM-only matching - simple string matching disabled`);

    const itemsToProcess: Array<{
      listing: ProduceListingFirestoreDocument;
      request: BuyerRequestFirestoreDocument;
    }> = [];

    // Build the processing array
    if (input.context === "listing_triggered") {
      const listing = input.triggeringItem as ProduceListingFirestoreDocument;
      const potentialRequests = input.potentialMatches as Array<BuyerRequestFirestoreDocument>;
      potentialRequests.forEach((request) => {
        itemsToProcess.push({listing, request});
      });
      console.log(`[Genkit] Processing listing ${listing.id} against ${potentialRequests.length} potential requests`);
    } else if (input.context === "request_triggered") {
      const request = input.triggeringItem as BuyerRequestFirestoreDocument;
      const potentialListings = input.potentialMatches as Array<ProduceListingFirestoreDocument>;
      potentialListings.forEach((listing) => {
        itemsToProcess.push({listing, request});
      });
      console.log(`[Genkit] Processing request ${request.id} against ${potentialListings.length} potential listings`);
    }

    functions.logger.info(`[Genkit] Processing ${itemsToProcess.length} potential matches using LLM`);
    
    // Only use LLM for matching
    console.log("[Genkit] Using LLM exclusively for all matching");
    
    // Process matches using LLM
    let usedLLM = false;
    console.log(`[Genkit] Proceeding to LLM-based matching for ${itemsToProcess.length} potential matches`);
    
    for (const itemPair of itemsToProcess) {
      const {listing, request} = itemPair;

      console.log(`\n[Genkit] USING LLM FOR: Listing ${listing.id} <-> Request ${request.id}`);

      // Access data fields correctly via .data property, ensure these fields are in your Zod schemas
      if (!listing.data.produceName || !request.data.produceNeededName) {
        console.log(`[Genkit] SKIPPING: Missing produce names`);
        continue; // Already logged warnings during simple matching
      }

      // Get location data
      const listingLocation = hasLocationData(listing.data.location) ? listing.data.location : {};
      const requestLocation = hasLocationData(request.data.deliveryLocation) ? request.data.deliveryLocation : {};
      const listingLocationStr = `${listingLocation.city || "Unknown"}, ${listingLocation.region || "Unknown"}`;
      const requestLocationStr = `${requestLocation.city || "Unknown"}, ${requestLocation.region || "Unknown"}`;
      
      // Calculate expiry/deadline information
      const daysUntilExpiry = calculateDaysUntil(listing.data.expiryTimestamp);
      const expiryDateStr = hasToDateMethod(listing.data.expiryTimestamp) ?
                            listing.data.expiryTimestamp.toDate().toISOString().split('T')[0] :
                            "Unknown";
      
      // Format prices for better comparison
      const listingPrice = listing.data.pricePerUnit ? `${listing.data.pricePerUnit} per ${listing.data.unit}` : "Not specified";
      const requestPrice = request.data.targetPricePerUnit ? `${request.data.targetPricePerUnit} per ${request.data.unit}` : "Not specified";
      
      console.log(`[Genkit] LLM INPUT DETAILS:
- Listing: ${listing.data.produceName} (${listing.data.category || "No category"})
- Quantity: ${listing.data.quantity || 0} ${listing.data.unit || "units"} @ ${listingPrice}
- Expiry: ${expiryDateStr} (${daysUntilExpiry} days remaining)
- Location: ${listingLocationStr}
- Request: ${request.data.produceNeededName} (${request.data.category || "No category"})
- Quantity Needed: ${request.data.quantity || 0} ${request.data.unit || "units"} @ ${requestPrice}
- Location: ${requestLocationStr}`);

      // Build a comprehensive prompt for the LLM with all factors
      const prompt = `You are an AI assistant helping to match fresh produce listings from farmers with requests from buyers.
Analyze the following Produce Listing and Buyer Request in detail:

Produce Listing Details:
- Name: ${listing.data.produceName || ""}
- Category: ${listing.data.category || ""}
- Available Quantity: ${listing.data.quantity || 0} ${listing.data.unit || "units"}
- Price: ${listingPrice}
- Expiry Date: ${expiryDateStr}
- Days Until Expiry: ${daysUntilExpiry}
- Current Date: ${currentDate.toISOString().split('T')[0]}
- Farmer's Notes: "${listing.data.description || "No notes provided"}" 
- Pickup Location: ${listingLocationStr}

Buyer Request Details:
- Needed Produce Name: ${request.data.produceNeededName || ""}
- Needed Category: ${request.data.category || ""}
- Desired Quantity: ${request.data.quantity || 0} ${request.data.unit || "units"}
- Desired Price Range: ${requestPrice}
- Buyer's Notes: "${request.data.description || "No notes provided"}"
- Delivery Location: ${requestLocationStr}

Considering all these factors (name/category similarity, quantity alignment, freshness based on days until expiry, price compatibility, and any specific notes from farmer or buyer), please:
1. Provide a suitability score for this match on a scale of 1 to 10 (where 10 is a perfect match).
2. Provide a concise rationale for your score, highlighting the key factors.

Give higher scores to matches where:
- The produce is expiring soon (within 7 days) but is still good
- The listing and delivery locations are in the same city
- The quantity available meets the buyer's needs
- The price aligns with buyer expectations

Output your response as a JSON object with "score" and "rationale" fields only.`;

      console.log(`[Genkit] Sending prompt to LLM (${prompt.length} characters)`);
      
      try {
        // Log the intent to use LLM
        functions.logger.info(`[Genkit] Attempting LLM call for Listing ${listing.id}/Request ${request.id}`);
        
        // Add a timeout to the generate call
        const timeout = new Promise((_, reject) => 
          setTimeout(() => reject(new Error('LLM call timed out after 15 seconds')), 15000)
        );
        
        console.log(`[Genkit] Waiting for LLM response...`);
        const llmResponsePromise = generate({
          model: gemini15Flash as ModelArgument, 
          prompt: prompt,
          config: {
            temperature: 0.1,
            maxOutputTokens: 500, // Increased for more detailed rationale
          },
        });

        // Race the API call against the timeout
        const llmResponse = await Promise.race([llmResponsePromise, timeout]);
        usedLLM = true;

        // Log the raw response for debugging
        console.log(`[Genkit] Got LLM raw response: ${JSON.stringify(llmResponse)}`);
        
        // Safe access to text property with fallback
        const responseText = llmResponse?.text?.trim?.() || "";
        console.log(`[Genkit] LLM response text: ${responseText}`);
        
        // Try to parse the JSON response
        let parsedResponse: LLMMatchResponse | null = null;
        try {
          // Try to extract JSON if it's wrapped in backticks or has other text
          const jsonMatch = responseText.match(/\{[\s\S]*?\}/);
          const jsonString = jsonMatch ? jsonMatch[0] : responseText;
          console.log(`[Genkit] Extracted JSON: ${jsonString}`);
          
          // Parse the JSON string
          const responseObj = JSON.parse(jsonString);
          const parseResult = LLMMatchResponseSchema.safeParse(responseObj);
          
          parsedResponse = parseResult.success ? parseResult.data : null;
          
          if (!parseResult.success) {
            console.error("[Genkit] Failed to validate LLM response:", parseResult.error);
          } else {
            console.log(`[Genkit] Successfully parsed response: score=${parsedResponse?.score}, rationale="${parsedResponse?.rationale}"`);
          }
        } catch (parseError) {
          console.error(`[Genkit] Error parsing LLM response as JSON: ${parseError}`, responseText);
        }
        
        // Calculate match score and rationale
        let aiMatchScore = 0.1; // Default low score
        let aiMatchRationale = "LLM response could not be parsed or was unclear.";

        if (parsedResponse) {
          // Convert 1-10 score to 0-1 range
          aiMatchScore = parsedResponse.score / 10;
          aiMatchRationale = parsedResponse.rationale;
          
          functions.logger.info(
            `[Genkit] LLM gave score ${parsedResponse.score}/10 (${aiMatchScore.toFixed(2)}) for Listing ${listing.id}/Request ${request.id}`
          );
          console.log(`[Genkit] Final LLM score: ${aiMatchScore.toFixed(2)}, rationale: ${aiMatchRationale}`);
        } else if (responseText.includes("stub_response")) {
          functions.logger.error(`[Genkit] Using stub response - API call likely failed`);
          aiMatchRationale = "Error: API call returned stub response";
          console.log(`[Genkit] Using stub response - API call likely failed`);
        } else if (responseText.includes("error:")) {
          functions.logger.error(`[Genkit] Error in API call: ${responseText}`);
          aiMatchRationale = `Error: ${responseText}`;
          console.log(`[Genkit] Error in API call: ${responseText}`);
        } else {
          // Fallback for when JSON parsing fails but there's meaningful text
          // Try to extract a numeric score if present
          const scoreMatch = responseText.match(/score\s*:?\s*(\d+)/);
          if (scoreMatch && scoreMatch[1]) {
            const extractedScore = parseInt(scoreMatch[1]);
            if (extractedScore >= 1 && extractedScore <= 10) {
              aiMatchScore = extractedScore / 10;
              aiMatchRationale = responseText.replace(/score\s*:?\s*\d+/, "").trim();
              console.log(`[Genkit] Extracted score ${extractedScore}/10 (${aiMatchScore.toFixed(2)}) from text response`);
            }
          } else {
            console.log(`[Genkit] Could not extract score from response, using default low score ${aiMatchScore}`);
          }
        }

        // Only add suggestions that meet the threshold
        if (aiMatchScore >= minScoreThreshold) {
          console.log(`[Genkit] ✓ Match score ${aiMatchScore.toFixed(2)} meets threshold ${minScoreThreshold}`);
          
          // Ensure farmerId and buyerId are present
          if (!listing.data.farmerId || !request.data.buyerId) {
            functions.logger.error(
              `[Genkit] Missing farmerId or buyerId. Listing: ${listing.id}, Request: ${request.id}`,
              {
                farmerId: listing.data.farmerId,
                buyerId: request.data.buyerId,
              }
            );
            console.log(`[Genkit] ✗ Missing farmerId or buyerId - skipping match`);
            continue;
          }

          // Default values for quantities and units to avoid undefined
          const suggestedQuantity = Math.min(
            Number(listing.data.quantity || 0),
            Number(request.data.quantity || 0)
          );
          
          const suggestedUnit = String(listing.data.unit || 
                                request.data.unit || 
                                "unit"); // Fallback value
          
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
          
          console.log(`[Genkit] ✓ Added LLM-based match to suggestions`);
        } else {
          console.log(`[Genkit] ✗ Match score ${aiMatchScore.toFixed(2)} below threshold ${minScoreThreshold} - ignoring`);
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
    console.log(`[Genkit] Flow completed using ${methodUsed}, found ${suggestions.length} matches`);
    
    functions.logger.info(
      `[Genkit] generateMatchSuggestionsFlow returning ${suggestions.length} suggestions.`
    );
    return suggestions;
  }
);
