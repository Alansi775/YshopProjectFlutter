import admin from '../config/firebase.js';

/**
 * جلب status لمتجر من فايرستور
 * @param {string} storeId
 * @returns {Promise<string|null>} status أو null إذا لم يوجد
 */
export async function getStoreStatusFromFirestore(storeId) {
  try {
    const doc = await admin.firestore().collection('stores').doc(storeId).get();
    if (!doc.exists) return null;
    const data = doc.data();
    return data?.status || null;
  } catch (error) {
    console.error('Error fetching store status from Firestore:', error);
    return null;
  }
}
