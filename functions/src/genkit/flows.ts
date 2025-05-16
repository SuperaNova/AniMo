import * as functions from "firebase-functions"; // For logger
import {z} from "zod";
import axios from "axios";
import {
  type MatchGenerationInput,
  type GenkitMatchOutput,
  type ProduceListingFirestoreDocument,
  type BuyerRequestFirestoreDocument,
} from "../models/aiMatchingTypes";
import { API_KEY } from "../registry";

const LLMMatchResponseSchema = z.object({
  score: z.number().min(1).max(10),
  rationale: z.string(),
});
type LLMMatchResponse = z.infer<typeof LLMMatchResponseSchema>;

function hasToDateMethod(obj: any): obj is { toDate(): Date } {
  return obj && typeof obj === 'object' && typeof obj.toDate === 'function';
}

function calculateDaysUntil(timestamp: any): number {
  if (!hasToDateMethod(timestamp)) return 999;
  const expiryDate = timestamp.toDate();
  const currentDate = new Date();
  const diffTime = expiryDate.getTime() - currentDate.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return diffDays > 0 ? diffDays : 0;
}

function hasLocationData(obj: any): obj is { city?: string; region?: string } {
  return obj && typeof obj === 'object';
}

// Direct API call to Google Gemini API (doesn't use Genkit)
async function callGeminiAPI(prompt: string): Promise<string> {
  try {
    const geminiEndpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${API_KEY}`;
    
    const response = await axios.post(geminiEndpoint, {
      contents: [{
        parts: [{
          text: prompt
        }]
      }],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 500,
      }
    });
    
    functions.logger.info("Gemini API response status:", response.status);
    
    // Extract the text from the response
    if (response.data && 
        response.data.candidates && 
        response.data.candidates[0] && 
        response.data.candidates[0].content && 
        response.data.candidates[0].content.parts && 
        response.data.candidates[0].content.parts[0]) {
      return response.data.candidates[0].content.parts[0].text;
    }
    
    // Fallback: return whole response stringified if we can't extract text
    return JSON.stringify(response.data);
  } catch (error: any) {
    functions.logger.error("Error calling Gemini API:", error.message);
    if (error.response) {
      functions.logger.error("API response error:", {
        status: error.response.status,
        data: error.response.data
      });
    }
    throw error;
  }
}

// Full implementation using direct API calls
export const generateMatchSuggestionsFlow = async (input: MatchGenerationInput): Promise<GenkitMatchOutput[]> => {
  functions.logger.info("[Genkit Flow] generateMatchSuggestionsFlow called with input:", {
    context: input.context,
    triggeringItemId: input.triggeringItem.id,
    potentialMatchesCount: input.potentialMatches.length,
    config: input.config,
  });

  const suggestions: GenkitMatchOutput[] = [];
  const minScoreThreshold = input.config?.minScoreThreshold || 0.7;
  const currentDate = new Date();
  const itemsToProcess: Array<{ listing: ProduceListingFirestoreDocument; request: BuyerRequestFirestoreDocument; }> = [];

  if (input.context === "listing_triggered") {
    const listing = input.triggeringItem as ProduceListingFirestoreDocument;
    const potentialRequests = input.potentialMatches as Array<BuyerRequestFirestoreDocument>;
    potentialRequests.forEach((request) => itemsToProcess.push({listing, request}));
  } else if (input.context === "request_triggered") {
    const request = input.triggeringItem as BuyerRequestFirestoreDocument;
    const potentialListings = input.potentialMatches as Array<ProduceListingFirestoreDocument>;
    potentialListings.forEach((listing) => itemsToProcess.push({listing, request}));
  }

  for (const itemPair of itemsToProcess) {
    const {listing, request} = itemPair;
    if (!listing || !listing.data || !request || !request.data || !listing.data.produceName || !request.data.produceNeededName) {
      console.log(`[Genkit Flow] SKIPPING pair due to missing data: L:${listing?.id} R:${request?.id}`);
      continue;
    }

    const listingLocation = hasLocationData(listing.data.location) ? listing.data.location : {};
    const requestLocation = hasLocationData(request.data.deliveryLocation) ? request.data.deliveryLocation : {};
    const listingLocationStr = `${listingLocation.city || "Unknown"}, ${listingLocation.region || "Unknown"}`;
    const requestLocationStr = `${requestLocation.city || "Unknown"}, ${requestLocation.region || "Unknown"}`;
    const daysUntilExpiry = calculateDaysUntil(listing.data.expiryTimestamp);
    const expiryDateStr = hasToDateMethod(listing.data.expiryTimestamp) ? listing.data.expiryTimestamp.toDate().toISOString().split('T')[0] : "Unknown";
    const listingPrice = listing.data.pricePerUnit ? `${listing.data.pricePerUnit} per ${listing.data.unit}` : "Not specified";
    const requestPrice = request.data.priceRangeMinPerUnit ? 
      `${request.data.priceRangeMinPerUnit} - ${request.data.priceRangeMaxPerUnit || "unspecified"} per ${request.data.quantityUnit || request.data.unit}` : 
      request.data.targetPricePerUnit ? `${request.data.targetPricePerUnit} per ${request.data.quantityUnit || request.data.unit}` : "Not specified";

    const prompt =
    `You are an AI assistant helping to match fresh produce listings from farmers with requests from buyers. Analyze the following Produce Listing and Buyer Request in detail:
    Produce Listing Details:
    - Name: ${listing.data.produceName || "Unknown produce"}
    - Category: ${listing.data.category || "Uncategorized"}
    - Available Quantity: ${listing.data.quantity || 0} ${listing.data.unit || "units"}
    - Price: ${listingPrice}
    - Expiry Date: ${expiryDateStr}
    - Days Until Expiry: ${daysUntilExpiry}
    - Current Date: ${currentDate.toISOString().split('T')[0]}
    - Farmer's Notes: "${listing.data.description || "No notes provided"}"
    - Pickup Location: ${listingLocationStr}
    Buyer Request Details:
    - Needed Produce Name: ${request.data.produceNeededName || "Unknown needed produce"}
    - Needed Category: ${request.data.produceNeededCategory || request.data.category || "Uncategorized"}
    - Desired Quantity: ${request.data.quantityNeeded || request.data.quantity || 0} ${request.data.quantityUnit || request.data.unit || "units"}
    - Desired Price Range: ${requestPrice}
    - Buyer's Notes: "${request.data.description || "No notes provided"}"
    - Delivery Location: ${requestLocationStr}
    Considering all these factors (name/category similarity, quantity alignment, freshness based on days until expiry, price compatibility, and any specific notes from farmer or buyer), please:
    1. Provide a suitability score for this match on a scale of 1 to 10 (where 10 is a perfect match).
    2. Provide a concise rationale for your score, highlighting the key factors.
    Output your response as a JSON object with "score" and "rationale" fields only.`;

    try {
      functions.logger.info(`[Direct LLM] Making direct API call to evaluate match between L:${listing.id}/R:${request.id}`);
      const timeout = new Promise<string>((_, reject) => 
        setTimeout(() => reject(new Error('LLM call timed out')), 15000)
      );

      // Use direct API call instead of Genkit
      const llmResponsePromise = callGeminiAPI(prompt);

      // Race against timeout
      const responseText = await Promise.race([llmResponsePromise, timeout]);
      
      functions.logger.info(`[Direct LLM] Received API response for L:${listing.id}/R:${request.id}:`, 
        { responseText: responseText.substring(0, 200) + (responseText.length > 200 ? '...' : '') });
      
      let parsedResponse: LLMMatchResponse | null = null;
      try {
        const jsonMatch = responseText.match(/\{[\s\S]*?\}/);
        const jsonString = jsonMatch ? jsonMatch[0] : responseText;
        const responseObj = JSON.parse(jsonString);
        const parseResult = LLMMatchResponseSchema.safeParse(responseObj);
        if (parseResult.success) parsedResponse = parseResult.data;
        else functions.logger.error("[Direct LLM] Response validation failed", {error: parseResult.error.format(), jsonString});
      } catch (parseError: any) {
        functions.logger.error("[Direct LLM] Response JSON parsing error", {message: parseError.message, responseText});
      }
      
      let aiMatchScore = parsedResponse ? parsedResponse.score / 10 : 0.1;
      let aiMatchRationale = parsedResponse ? parsedResponse.rationale : "LLM response parsing failed.";

      if (aiMatchScore >= minScoreThreshold) {
        if (!listing.data.farmerId || !request.data.buyerId) {
          functions.logger.error(`[Direct LLM] Missing farmerId/buyerId for L:${listing.id}/R:${request.id}`);
          continue;
        }
        suggestions.push({
          listingId: listing.id,
          farmerId: listing.data.farmerId as string,
          buyerRequestId: request.id,
          buyerId: request.data.buyerId as string,
          suggestedOrderQuantity: Math.min(Number(listing.data.quantity||0), Number(request.data.quantity||0)),
          suggestedOrderQuantityUnit: String(listing.data.unit || request.data.unit || "unit"),
          aiMatchScore: aiMatchScore,
          aiMatchRationale: aiMatchRationale,
        });
      }
    } catch (error: any) {
      functions.logger.error(`[Direct LLM] Error in API processing for L:${listing.id}/R:${request.id}`, {message: error.message, stack: error.stack});
    }
  }
  return suggestions;
};
