import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";
import {REGION} from "../config"; // Assuming a config file for region

export const helloWorld = onRequest(
  {region: REGION},
  (request, response) => {
    logger.info(`Hello logs from ${REGION}!`, {structuredData: true});
    response.send(`Hello from Firebase (${REGION}), AniMo!`);
  },
);
