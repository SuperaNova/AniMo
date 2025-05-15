import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {Timestamp, FieldValue} from "firebase-admin/firestore";
import {db} from "../admin";
import {REGION} from "../config";
import {initiateFarmerPayoutToPlatformQueue} from "../helpers/payoutHelper"; // Import the helper

export const onOrderStatusUpdate = onDocumentWritten(
  {
    document: "orders/{orderId}",
    region: REGION,
  },
  async (event) => {
    logger.info("onOrderStatusUpdate triggered", {params: event.params});

    if (!event.data) {
      logger.info("No data associated with event (order likely deleted).");
      return;
    }
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    if (!afterData) {
      logger.info("Order deleted, no further action.");
      return;
    }

    const orderId = event.params.orderId;
    const newStatus = afterData.status;
    const oldStatus = beforeData?.status;

    if (newStatus !== oldStatus) {
      logger.info(`Order ${orderId} from '${oldStatus || "N/A"}' to '${newStatus}'.`);

      if (newStatus === "out_for_delivery") {
        logger.info(`Placeholder: Notify buyer ${afterData.buyerId} - Out for Delivery.`);
      } else if (newStatus === "delivered_pending_buyer_confirmation") {
        logger.info(`Placeholder: Notify buyer ${afterData.buyerId} - Order Delivered.`);
      } else if (newStatus === "completed") {
        logger.info(`Placeholder: Notify buyer ${afterData.buyerId} & farmer ${afterData.farmerId} - Order Completed.`);

        const farmerId = afterData.farmerId;
        const goodsPrice = afterData.totalGoodsPrice;
        const currency = afterData.currency || "PHP";

        if (farmerId && typeof goodsPrice === "number" && goodsPrice > 0) {
          try {
            logger.info(`Order ${orderId} completed. Initiating payout.`);
            await initiateFarmerPayoutToPlatformQueue(orderId, farmerId, goodsPrice, currency);
            await db.collection("orders").doc(orderId).update({
              payoutInitiationTimestamp: Timestamp.now(),
              lastUpdated: Timestamp.now(),
            });
          } catch (payoutError) {
            logger.error("Failed to initiate payout:", {orderId, payoutError});
          }
        } else {
          logger.warn("Cannot initiate payout:", {orderId, farmerId, goodsPrice});
        }
      } else if (newStatus === "cancelled_by_farmer" || newStatus === "cancelled_by_buyer" || newStatus === "delivery_failed") {
        logger.info(`Placeholder: Notify for cancelled/failed order ${orderId}.`);
        const noRevertStatuses = ["driver_picked_up_enroute_to_delivery", "delivered_pending_buyer_confirmation", "completed"];
        if (!noRevertStatuses.includes(oldStatus) && afterData.listingId && afterData.orderedQuantity > 0) {
          try {
            const listingRef = db.collection("produceListings").doc(afterData.listingId);
            await listingRef.update({
              quantityCommitted: FieldValue.increment(-afterData.orderedQuantity),
              lastUpdated: Timestamp.now(),
            });
            logger.info(`Reverted quantityCommitted for ${afterData.listingId}.`);
          } catch (revertError) {
            logger.error(`Failed to revert quantity for ${afterData.listingId}`, {revertError});
          }
        }
      }
    }
  },
);
