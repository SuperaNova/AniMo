import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {Timestamp, FieldValue} from "firebase-admin/firestore";
import {db} from "../admin";
import {REGION} from "../config";

export const createOrderFromAcceptedMatch = onDocumentWritten(
  {
    document: "matchSuggestions/{suggestionId}",
    region: REGION,
  },
  async (event) => {
    logger.info("createOrderFromAcceptedMatch triggered", {params: event.params});

    if (!event.data) {
      logger.info("No data associated with the event. Likely a deletion.");
      return;
    }

    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    if (!afterData) {
      logger.info("MatchSuggestion deleted, no action for order creation.");
      return;
    }

    const orderCreationStatus = "both_accepted_order_created";
    const previousStatus = beforeData?.status;

    if (afterData.status === orderCreationStatus && previousStatus !== orderCreationStatus) {
      logger.info(`Match ${event.params.suggestionId} status to ${orderCreationStatus}. Creating order.`);

      const matchSuggestion = afterData;
      const now = Timestamp.now();
      const orderId = db.collection("orders").doc().id;

      try {
        const farmerDoc = await db.collection("appUsers").doc(matchSuggestion.farmerId).get();
        const buyerDoc = await db.collection("appUsers").doc(matchSuggestion.buyerId).get();
        const listingDoc = await db.collection("produceListings").doc(matchSuggestion.listingId).get();

        if (!farmerDoc.exists || !buyerDoc.exists || !listingDoc.exists) {
          logger.error("Farmer, buyer, or listing not found for match.", {matchId: event.params.suggestionId});
          await db.collection("matchSuggestions").doc(event.params.suggestionId).update({
            status: "error_creating_order",
            lastUpdated: now,
            errorMessage: "Farmer, buyer, or listing not found.",
          });
          return;
        }

        const farmerData = farmerDoc.data();
        const buyerData = buyerDoc.data();
        const listingData = listingDoc.data();

        const newOrder = {
          orderId: orderId,
          orderCreationDateTime: now,
          buyerId: matchSuggestion.buyerId,
          buyerName: buyerData?.displayName || "N/A",
          farmerId: matchSuggestion.farmerId,
          farmerName: farmerData?.displayName || "N/A",
          listingId: matchSuggestion.listingId,
          produceDetailsSnapshot: {
            produceName: listingData?.produceName,
            pricePerUnit: listingData?.pricePerUnit,
            quantityUnit: listingData?.quantityUnit,
          },
          orderedQuantity: matchSuggestion.suggestedOrderQuantity,
          orderedQuantityUnit: matchSuggestion.suggestedOrderQuantityUnit,
          totalGoodsPrice: (listingData?.pricePerUnit || 0) * (matchSuggestion.suggestedOrderQuantity || 0),
          currency: listingData?.currency || "PHP",
          pickupLocation: listingData?.pickupLocation,
          deliveryLocation: matchSuggestion.deliveryLocation || buyerData?.defaultDeliveryLocation,
          status: "pending_farmer_confirmation",
          lastUpdated: now,
          originatingMatchSuggestionId: event.params.suggestionId,
          originatingBuyerRequestId: matchSuggestion.buyerRequestId || null,
        };

        const batch = db.batch();
        const orderRef = db.collection("orders").doc(orderId);
        batch.set(orderRef, newOrder);

        const listingRef = db.collection("produceListings").doc(matchSuggestion.listingId);
        batch.update(listingRef, {
          quantityCommitted: FieldValue.increment(matchSuggestion.suggestedOrderQuantity),
          lastUpdated: now,
        });

        const matchRef = db.collection("matchSuggestions").doc(event.params.suggestionId);
        batch.update(matchRef, {
          relatedOrderId: orderId,
          status: "order_created",
          lastUpdated: now,
        });

        if (matchSuggestion.buyerRequestId) {
          const buyerRequestRef = db.collection("buyerRequests").doc(matchSuggestion.buyerRequestId);
          batch.update(buyerRequestRef, {
            fulfilledByOrderIds: FieldValue.arrayUnion(orderId),
            totalQuantityFulfilled: FieldValue.increment(matchSuggestion.suggestedOrderQuantity),
            lastUpdated: now,
          });
        }

        await batch.commit();
        logger.info(`Order ${orderId} created from Match ${event.params.suggestionId}.`);
      } catch (error) {
        logger.error("Error creating order:", {matchId: event.params.suggestionId, error});
        try {
          await db.collection("matchSuggestions").doc(event.params.suggestionId).update({
            status: "error_creating_order",
            lastUpdated: Timestamp.now(),
            errorMessage: "Internal error during order creation.",
          });
        } catch (updateError) {
          logger.error("Failed to update match to error state", {updateError});
        }
      }
    } else {
      logger.info(`Match ${event.params.suggestionId} status '${afterData?.status}', not '${orderCreationStatus}' or no change.`);
    }
  },
);
