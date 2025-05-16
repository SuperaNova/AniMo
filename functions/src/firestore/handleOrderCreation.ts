import {onDocumentWritten, FirestoreEvent, Change} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { admin } from "../admin"; // Import initialized admin instance
import {REGION} from "../config";
import {
  MatchSuggestionFirestoreData,
} from "../models/aiMatchingTypes"; // Removed unused ProduceListingDocData, BuyerRequestDocData for now
// import { OrderDocData, OrderStatus, PaymentStatus } from "../models/orderTypes"; // Commented out for now

// Initialize Firestore
// const db = admin.firestore(); // Commented out for now

// Function to trigger when a MatchSuggestion indicates both parties have accepted.
export const createOrderFromAcceptedMatch = onDocumentWritten(
  {
    document: "matchSuggestions/{suggestionId}",
    region: REGION,
  },
  async (event: FirestoreEvent<Change<admin.firestore.DocumentSnapshot> | undefined, {suggestionId: string}>) => {
    if (!event.data) {
      logger.info("No event data, likely a deletion, skipping.");
      return null;
    }

    // Explicitly type the data from snapshots
    const beforeData = event.data.before.data() as MatchSuggestionFirestoreData | undefined;
    const afterData = event.data.after.data() as MatchSuggestionFirestoreData | undefined;
    const suggestionId = event.params.suggestionId;

    // Check if the document was created or updated
    if (!event.data.after.exists || !afterData) {
      logger.info(`MatchSuggestion ${suggestionId} was deleted, skipping order creation.`);
      return null;
    }

    // --- Trigger Condition: Status changed to 'order_processing' ---
    // We only want to create an order if the status specifically becomes 'order_processing'.
    // This prevents re-triggering if other fields in an already 'order_processing' suggestion change.
    const statusBefore = beforeData?.status;
    const statusAfter = afterData.status;

    if (statusAfter !== "order_processing" || statusBefore === "order_processing") {
      logger.info(
        `MatchSuggestion ${suggestionId} status is '${statusAfter}' (before: '${statusBefore}'). ` +
        "Not 'order_processing' or already processed, skipping order creation."
      );
      return null;
    }

    logger.info(`MatchSuggestion ${suggestionId} accepted (status: ${statusAfter}), proceeding to create order.`);

    // TODO: Implement the core logic:
    // 1. Validate required fields in afterData (MatchSuggestion)
    // 2. Fetch ProduceListing (using afterData.listingId)
    // 3. Fetch BuyerRequest (using afterData.buyerRequestId - if it exists)
    // 4. Construct the OrderDocData object:
    //    - Populate with details from MatchSuggestion, ProduceListing, BuyerRequest.
    //    - Calculate totalPrice.
    //    - Set initial OrderStatus (e.g., OrderStatus.PENDING_DRIVER_ASSIGNMENT).
    //    - Set initial PaymentStatus (e.g., PaymentStatus.PENDING_COD).
    //    - Use admin.firestore.FieldValue.serverTimestamp() for timestamps.
    // 5. Create a new document in the "orders" collection.
    // 6. Update MatchSuggestion status to "order_created".
    // 7. Update quantity on ProduceListing (e.g., decrement available quantity or update committed quantity).
    // 8. Update BuyerRequest (e.g., totalQuantityFulfilled).
    //    - All these writes should ideally happen in a Firestore batch or transaction for atomicity.

    logger.warn(`Order creation logic for ${suggestionId} is not yet implemented!`);
    return null;
  }
);

// TODO:
// 1. Define the OrderDocData interface (likely in aiMatchingTypes.ts or a new models/orderTypes.ts)
// 2. Refine the trigger condition for createOrderFromAcceptedMatch (e.g., specific status change).
// 3. Implement the core logic:
//    - Read MatchSuggestion, ProduceListing, BuyerRequest.
//    - Create and write the Order document.
//    - Update statuses and quantities on related documents.
