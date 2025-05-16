import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import * as admin from "firebase-admin"; // Import the full admin namespace

// Check if the app is already initialized to prevent duplicate initializations
if (!admin.apps.length) {
  initializeApp();
}

const db = getFirestore();

export {db, admin};
