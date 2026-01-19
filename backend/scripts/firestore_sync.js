// سكريبت مزامنة تلقائية من فايرستور إلى MySQL عند أي تغيير
// يعمل بشكل دائم (long-running process)
// يتطلب: npm install firebase-admin mysql2 dotenv

import admin from 'firebase-admin';
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

// استيراد ملف الخدمة بصيغة ES module
import serviceAccount from '../home-720ef-firebase-adminsdk-8yjvx-4619a2dce7.json' assert { type: 'json' };

dotenv.config();

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const firestore = admin.firestore();

// إعداد MySQL
const pool = mysql.createPool({
  host: process.env.MYSQL_HOST,
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
});

// مراقبة تغييرات المتاجر في فايرستور
function listenToStoreRequests() {
  firestore.collection('storeRequests').onSnapshot(async (snapshot) => {
    for (const change of snapshot.docChanges()) {
      const doc = change.doc;
      const data = doc.data();
      const storeId = doc.id;
      if (!data) continue;

      // فقط إذا كان storeType موجود
      if (!data.storeType) continue;

      // إذا لم يكن الطلب Approved، نتحقق من حالة التحقق من البريد الإلكتروني للمالك
      let shouldSync = false;
      if (data.status && data.status === 'Approved') {
        shouldSync = true;
      } else if (data.ownerUid) {
        try {
          const fbUser = await admin.auth().getUser(data.ownerUid);
          if (fbUser && fbUser.emailVerified) shouldSync = true;
        } catch (e) {
          // لا يوجد مستخدم في Firebase مع هذا الـ UID أو خطأ في الشبكة
          console.warn(`Could not fetch Firebase user for UID ${data.ownerUid}: ${e.message}`);
        }
      }

      if (!shouldSync) {
        // نتخطى المزامنة حتى يتم الموافقة أو يتم التحقق من البريد الإلكتروني
        continue;
      }

      // تحديث أو إدراج في MySQL
      try {
        await pool.query(
          `INSERT INTO stores (owner_uid, name, store_type, phone, address, status, icon_url, description, email)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE
             name = VALUES(name),
             store_type = VALUES(store_type),
             phone = VALUES(phone),
             address = VALUES(address),
             status = VALUES(status),
             icon_url = VALUES(icon_url),
             description = VALUES(description),
             email = VALUES(email)`,
          [
            data.ownerUid || storeId,
            data.storeName || '',
            data.storeType || '',
            data.phone || '',
            data.address || '',
            data.status || 'Pending',
            data.iconUrl || '',
            data.description || '',
            data.email || '',
          ]
        );
        console.log(` تمت مزامنة المتجر (${storeId}) بنجاح`);
      } catch (err) {
        console.error(`❌ خطأ في مزامنة المتجر (${storeId}):`, err.message);
      }
    }
  }, (err) => {
    console.error('Firestore listener error:', err);
  });
}

listenToStoreRequests();

console.log('مزامنة المتاجر من فايرستور إلى MySQL تعمل الآن...');
