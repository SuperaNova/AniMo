/**
 * Import function triggers from their respective submodules:
 */
// Import and config modules
import {genkit} from "genkit"; // Use main genkit import
import {googleAI, gemini15Flash} from "@genkit-ai/googleai"; // Corrected package name, import gemini15Flash
// Import what's available in 1.8.0
// Temporarily disable Firebase telemetry as it seems to be causing errors
// import { enableFirebaseTelemetry } from "@genkit-ai/firebase";
import {defineString} from "firebase-functions/params"; // For Firebase params/secrets
import * as functions from "firebase-functions"; // For logging

// Initialize admin is handled in admin.ts and will be imported by the functions that need it

// Define the secret parameter (don't call .value() here)
const geminiApiKey = defineString("GEMINI_API_KEY");

// Try to initialize Genkit properly to avoid registry errors
try {
  // Initialize Genkit with detailed logging
  functions.logger.info("Initializing Genkit with Gemini model...");
  
  // For development testing, try fetching the key directly to validate it exists
  functions.logger.info(
    `API Key configuration: ${geminiApiKey ? "Parameter exists" : "Missing"}`
  );
  
  // Try to use the direct API key value for more reliable operation
  // This is a workaround for potential issues with the parameter object
  const apiKeyValue = geminiApiKey.value();
  functions.logger.info(`API Key value ${apiKeyValue ? "found" : "not available"}`);
  
  // Configure and initialize Genkit using the new pattern
  const genkitInstance = genkit({
    plugins: [
      // Use the direct string value for the API key
      googleAI({
        apiKey: apiKeyValue || (geminiApiKey as unknown as string),
      }),
    ],
    model: gemini15Flash, // Set gemini15Flash as the default model
    // Don't enable metrics until we have basic functionality working
  });
  
  // Log that we successfully initialized
  functions.logger.info("Genkit initialized successfully", { 
    instance: genkitInstance ? "Created" : "Failed" 
  });
} catch (error) {
  functions.logger.error("Error initializing Genkit:", error);
}

// Scheduled Triggers
export * from "./scheduled/expireListingsAndRequests";

// Firestore Triggers
export * from "./firestore/createOrderFromAcceptedMatch";
export * from "./firestore/onOrderStatusUpdate";
export * from "./firestore/handleAiMatching";
export * from "./firestore/calculateDeliveryFee";
