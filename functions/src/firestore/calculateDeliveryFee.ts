import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
// import {db} from "../admin"; // Will be needed when implemented
import {REGION} from "../config";

export const calculateDeliveryFee = onDocumentWritten(
  {
    document: "orders/{orderId}",
    region: REGION,
  },
  async (event) => {
    if (!event.data?.after.exists) {
      logger.info("Order deleted, no delivery calculation needed.");
      return;
    }
    const orderData = event.data.after.data();
    const previousOrderData = event.data.before.data();

    const triggerStatus = "farmer_confirmed_awaiting_driver";
    if (orderData?.status === triggerStatus && previousOrderData?.status !== triggerStatus) {
      logger.info("STUB: Calculate delivery fee triggered", {orderId: event.params.orderId});
      logger.warn("calculateDeliveryFee requires Google Maps Platform integration.");
      // TODO: Google Maps logic, update order, notify drivers
    }
  },
);
