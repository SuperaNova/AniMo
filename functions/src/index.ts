/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import "./admin";

// HTTP Triggers
export * from "./http/helloWorld";

// Scheduled Triggers
export * from "./scheduled/expireListingsAndRequests";

// Firestore Triggers
export * from "./firestore/createOrderFromAcceptedMatch";
export * from "./firestore/onOrderStatusUpdate";
export * from "./firestore/handleAiMatching"; // Exports both onNewProduceListing & onNewBuyerRequest
export * from "./firestore/calculateDeliveryFee";

// Note: Helper functions (like payoutHelper) are not exported here as they are not Cloud Function triggers.
// They are imported directly by the functions that need them.
