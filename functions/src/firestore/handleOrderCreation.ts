import {onDocumentWritten, FirestoreEvent, Change} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { admin } from "../admin"; // Import initialized admin instance
import {REGION} from "../config";
import {
  MatchSuggestionFirestoreData,
} from "../models/aiMatchingTypes";

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


    logger.warn(`Order creation logic for ${suggestionId} is not yet implemented!`);
    return null;
  }
);
