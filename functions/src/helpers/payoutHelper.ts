import * as logger from "firebase-functions/logger";
import {Timestamp} from "firebase-admin/firestore";
import {db} from "../admin"; // Import db from admin.ts

/**
 * @description Adds a farmer payout request to the Firestore "payoutQueue" collection.
 * This function is intended to be called when an order is completed and payment
 * for the goods has been secured by the platform, initiating the process to pay the farmer.
 *
 * @param {string} orderId - The ID of the order for which the payout is being initiated.
 * @param {string} farmerId - The ID of the farmer who needs to be paid.
 * @param {number} amount - The monetary amount to be paid to the farmer.
 * @param {string} currency - The currency code for the payout amount (e.g., "PHP").
 * @return {Promise<string>} A promise that resolves with the ID of the newly created payout queue document.
 * @throws {Error} Throws an error if adding the payout request to the queue fails.
 */
export async function initiateFarmerPayoutToPlatformQueue(
  orderId: string,
  farmerId: string,
  amount: number,
  currency: string
): Promise<string> { // Added explicit return type for clarity, matching JSDoc
  const now = Timestamp.now();
  const payoutData = {
    orderId,
    farmerId,
    amount,
    currency,
    status: "pending_processing", // Initial status
    requestTimestamp: now,
    lastUpdated: now,
  };
  try {
    const payoutRef = await db.collection("payoutQueue").add(payoutData);
    logger.info(`Payout request ${payoutRef.id} added to queue for Order ${orderId}.`);
    return payoutRef.id;
  } catch (error) {
    logger.error("Error adding payout to queue:", {orderId, error});
    throw error; // Re-throw the error to be handled by the caller
  }
}
