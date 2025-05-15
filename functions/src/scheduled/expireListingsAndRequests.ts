import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {Timestamp} from "firebase-admin/firestore";
import {db} from "../admin"; // Import db from admin.ts
import {REGION} from "../config";

export const expireListingsAndRequests = onSchedule(
  {
    schedule: "every day 01:00",
    timeZone: "Asia/Manila",
    region: REGION,
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  async (event) => {
    logger.info("Starting expireListingsAndRequests job.", {event});
    const now = Timestamp.now();
    const batch = db.batch();
    let expiredItemsCount = 0;

    try {
      // 1. Expire ProduceListings
      const listingsQuery = db.collection("produceListings")
        .where("expiryTimestamp", "<=", now)
        .where("status", "in", ["available", "partially_committed"]);
      const expiredListingsSnapshot = await listingsQuery.get();
      expiredListingsSnapshot.forEach((doc) => {
        logger.info(`Expiring ProduceListing: ${doc.id}`);
        batch.update(doc.ref, {status: "expired", lastUpdated: now});
        expiredItemsCount++;
      });

      // 2. Expire BuyerRequests
      const requestsQuery = db.collection("buyerRequests")
        .where("deliveryDeadline", "<=", now)
        .where("status", "in", ["pending_match", "partially_fulfilled"]);
      const expiredRequestsSnapshot = await requestsQuery.get();
      expiredRequestsSnapshot.forEach((doc) => {
        const logMsg = `Expiring BuyerRequest: ${doc.id} due to deadline.`;
        logger.info(logMsg);
        batch.update(doc.ref, {status: "expired", lastUpdated: now});
        expiredItemsCount++;
      });

      // 3. Expire MatchSuggestions
      const threeDaysInMillis = 3 * 24 * 60 * 60 * 1000;
      const threeDaysAgo = Timestamp.fromMillis(
        now.toMillis() - threeDaysInMillis,
      );
      const suggestionStatusesToExpire = [
        "pending_farmer_action",
        "pending_buyer_action",
        "farmer_accepted_pending_buyer",
        "buyer_accepted_pending_farmer",
      ];
      const suggestionsQuery = db.collection("matchSuggestions")
        .where("creationTimestamp", "<=", threeDaysAgo)
        .where("status", "in", suggestionStatusesToExpire);
      const expiredSuggestionsSnapshot = await suggestionsQuery.get();
      expiredSuggestionsSnapshot.forEach((doc) => {
        const logMsg = `Expiring MatchSuggestion: ${doc.id} due to age.`;
        logger.info(logMsg);
        batch.update(doc.ref, {status: "expired", lastUpdated: now});
        expiredItemsCount++;
      });

      if (expiredItemsCount > 0) {
        await batch.commit();
        logger.info(`Successfully expired ${expiredItemsCount} items.`);
      } else {
        logger.info("No items found to expire in this run.");
      }
    } catch (error) {
      logger.error("Error in expireListingsAndRequests job", {error});
    }
  },
);
