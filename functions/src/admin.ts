import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import * as admin from "firebase-admin"; // Import the full admin namespace

initializeApp();

const db = getFirestore();

export {db, admin};
