/**
 * Centralized registry for Genkit API key management.
 */
import * as functions from "firebase-functions";

// Try to get API key from environment
export const API_KEY = process.env.GEMINI_API_KEY || "AIzaSyBBJHmEkiNvfD0ONSal21uXQM5qmV7kPmU"; // Replace with your actual API key in production

// Log API key for debugging
functions.logger.info("API Key configured for Genkit", { 
  keyConfigured: !!API_KEY
}); 