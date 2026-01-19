import admin from 'firebase-admin';
import dotenv from 'dotenv';

dotenv.config();

let auth = null;
let firebaseInitialized = false;
let initializationAttempted = false; //  Prevent repeated initialization attempts

//  DISABLED: Firebase Admin initialization
// All store operations use MySQL API only
// Firestore sync is disabled - no need to initialize Firebase
console.log('⚠️ Firebase Admin initialization DISABLED - Using MySQL API only');
firebaseInitialized = false;
initializationAttempted = true;

export { auth, firebaseInitialized, initializationAttempted };
export default admin;
