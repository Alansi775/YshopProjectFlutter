import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import pool from '../config/database.js';

// Firestore sync for storeRequests -> stores table
export function startFirestoreSync() {
  //  DISABLED: Firestore sync is disabled to avoid delays in Dashboard updates
  // All data operations use MySQL directly via API
  // Firestore is only used for email verification
  console.log('⚠️ Firestore sync DISABLED - Using MySQL API only for store updates');
  return;
  
  // Try to ensure Firebase Admin is initialized. Prefer local service account JSON if present.
  try {
    if (!admin.apps || admin.apps.length === 0) {
      // try local file in backend/ directory
      const saPath = path.resolve(process.cwd(), 'home-720ef-firebase-adminsdk-8yjvx-4619a2dce7.json');
      if (fs.existsSync(saPath)) {
        const sa = JSON.parse(fs.readFileSync(saPath, 'utf8'));
        admin.initializeApp({ credential: admin.credential.cert(sa) });
        console.log('Firebase Admin initialized from local service account JSON');
      } else {
        console.warn('Firebase Admin not initialized and service account JSON not found; proceeding without Firestore sync');
        return;
      }
    }
  } catch (e) {
    console.warn('Failed to initialize Firebase Admin for firestoreSync:', e.message);
    return;
  }

  const firestore = admin.firestore();

  firestore.collection('storeRequests').onSnapshot(async (snapshot) => {
    for (const change of snapshot.docChanges()) {
      const doc = change.doc;
      const data = doc.data();
      const storeId = doc.id;
      if (!data) continue;

      // require at least a storeType to consider
      if (!data.storeType) continue;

      // Upsert immediately into MySQL so store appears in `stores` right away.
      // Map Firestore status to MySQL status: 'Approved', 'Pending', 'Suspended', 'Rejected'
      const ownerUid = data.ownerUid || storeId;
      const dbStatus = data.status || 'Pending';

      console.log(` Firestore sync: store ${storeId} (owner ${ownerUid}), Firestore status=${data.status}, using dbStatus=${dbStatus}, changeType=${change.type}`);

      try {
        // Try to find an existing user with the same email. If found, reuse that UID
        let ownerUidToUse = ownerUid;
        if (data.email) {
          try {
            const [rows] = await pool.query('SELECT uid FROM users WHERE email = ? LIMIT 1', [data.email]);
            if (Array.isArray(rows) && rows.length > 0 && rows[0].uid) {
              ownerUidToUse = rows[0].uid;
            } else {
              // insert the user record if it doesn't exist
              await pool.query(
                `INSERT IGNORE INTO users (uid, email, display_name) VALUES (?, ?, ?)`,
                [ownerUidToUse, data.email || '', data.ownerName || data.storeName || '']
              );
            }
          } catch (e) {
            console.warn(`Could not query/insert user for email ${data.email}: ${e.message}`);
            // fallback: ensure ownerUid exists
            try {
              await pool.query(`INSERT IGNORE INTO users (uid, email, display_name) VALUES (?, ?, ?)`, [ownerUidToUse, data.email || '', data.ownerName || data.storeName || '']);
            } catch (e2) {
              console.warn(`Fallback insert failed for ${ownerUidToUse}: ${e2.message}`);
            }
          }
        } else {
          // no email provided: ensure user by UID
          try {
            await pool.query(`INSERT IGNORE INTO users (uid, email, display_name) VALUES (?, ?, ?)`, [ownerUidToUse, '', data.ownerName || data.storeName || '']);
          } catch (e) {
            console.warn(`Could not ensure user ${ownerUidToUse} exists: ${e.message}`);
          }
        }

        // Only set/overwrite icon_url when Firestore provides a non-empty value.
        // This prevents an empty/missing field in Firestore from clearing a previously uploaded image path in MySQL.
        console.log(`📊 Firestore sync: About to execute SQL for store ${storeId}, setting status to '${dbStatus}'`);
        await pool.query(
          `INSERT INTO stores (owner_uid, name, store_type, phone, address, status, icon_url, description, email)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE
             name = VALUES(name),
             store_type = VALUES(store_type),
             phone = VALUES(phone),
             address = VALUES(address),
             status = VALUES(status),
             icon_url = IF(VALUES(icon_url) != '', VALUES(icon_url), icon_url),
             description = VALUES(description),
             email = VALUES(email)`,
          [
            ownerUidToUse,
            data.storeName || '',
            data.storeType || '',
            data.phone || '',
            data.address || '',
            dbStatus,
            // pass NULL when no icon is provided instead of empty string
            data.iconUrl && data.iconUrl !== '' ? data.iconUrl : null,
            data.description || '',
            data.email || '',
          ]
        );

        try { await doc.ref.update({ syncedToMySQL: true }); } catch (e) {}

        // Verify the update
        try {
          const [verifyRows] = await pool.query('SELECT status FROM stores WHERE id IN (SELECT id FROM stores WHERE owner_uid = ?) LIMIT 1', [ownerUidToUse]);
          const actualStatus = verifyRows[0]?.status;
          console.log(` Firestore sync: store ${storeId} synced, status=${dbStatus}, verified in DB: status='${actualStatus}'`);
        } catch (e) {
          console.log(`Firestore -> MySQL sync: store ${storeId} (owner ${ownerUid}) synced, status=${dbStatus}`);
        }
      } catch (err) {
        console.error(`Failed to sync store ${storeId}:`, err.message);
      }
    }
  }, (err) => {
    console.error('Firestore listener error:', err);
  });

  console.log('Started Firestore storeRequests sync');
}

export default startFirestoreSync;
