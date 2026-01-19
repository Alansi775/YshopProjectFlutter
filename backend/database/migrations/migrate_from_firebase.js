import admin from 'firebase-admin';
import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Initialize Firebase - try multiple paths
let firebaseInitialized = false;
const credentialPaths = [
  path.join(__dirname, '../../firebase-adminsdk.json'),
  path.join(__dirname, '../../../firebase-adminsdk.json'),
  path.join(__dirname, '../../../ios/Runner/GoogleService-Info.plist'), // iOS path
];

for (const credPath of credentialPaths) {
  if (fs.existsSync(credPath)) {
    try {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(fs.readFileSync(credPath, 'utf8'))),
      });
      firebaseInitialized = true;
      logger.info(` Firebase initialized with credentials from: ${credPath}`);
      break;
    } catch (e) {
      logger.warn(`⚠️ Failed to initialize Firebase with ${credPath}:`, e.message);
    }
  }
}

if (!firebaseInitialized) {
  logger.error('❌ Firebase credentials not found. Please provide firebase-adminsdk.json');
  logger.info('Get it from Firebase Console: Project Settings > Service Accounts > Generate New Private Key');
  process.exit(1);
}

const db = admin.firestore();

async function migrateUsers() {
  logger.info(' Starting to migrate users from Firebase...');
  try {
    const usersSnapshot = await db.collection('users').get();
    let migratedCount = 0;
    let skippedCount = 0;

    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      const uid = doc.id;
      
      try {
        const connection = await pool.getConnection();
        
        // Check if user already exists
        const [existingUser] = await connection.execute(
          'SELECT id FROM users WHERE uid = ?',
          [uid]
        );

        if (existingUser.length === 0) {
          // Insert new user
          await connection.execute(
            `INSERT INTO users (uid, email, display_name, phone, created_at, updated_at)
             VALUES (?, ?, ?, ?, NOW(), NOW())`,
            [
              uid,
              userData.email || '',
              userData.displayName || '',
              userData.phone || ''
            ]
          );
          migratedCount++;
          logger.info(`   Migrated user: ${userData.email}`);
        } else {
          skippedCount++;
          logger.info(`  ⏭️ User already exists: ${userData.email}`);
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error migrating user ${uid}:`, err.message);
      }
    }

    logger.info(` Users migration complete: ${migratedCount} added, ${skippedCount} skipped`);
    return { migratedCount, skippedCount };
  } catch (error) {
    logger.error('❌ Error in migrateUsers:', error);
    throw error;
  }
}

async function migrateStores() {
  logger.info(' Starting to migrate stores from Firebase...');
  try {
    const storesSnapshot = await db.collection('storeRequests').get();
    let migratedCount = 0;
    let skippedCount = 0;

    for (const doc of storesSnapshot.docs) {
      const storeData = doc.data();
      const uid = doc.id;

      try {
        const connection = await pool.getConnection();

        // Check if store already exists
        const [existingStore] = await connection.execute(
          'SELECT id FROM stores WHERE owner_uid = ?',
          [uid]
        );

        if (existingStore.length === 0) {
          // Get user to verify exists
          const [user] = await connection.execute(
            'SELECT id FROM users WHERE uid = ?',
            [uid]
          );

          if (user.length > 0) {
            await connection.execute(
              `INSERT INTO stores (name, description, phone, address, latitude, longitude, icon_url, owner_uid, is_active, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, true, NOW(), NOW())`,
              [
                storeData.storeName || 'Unnamed Store',
                storeData.description || '',
                storeData.phoneNumber || '',
                storeData.address || '',
                storeData.latitude || 0,
                storeData.longitude || 0,
                storeData.storeIconUrl || '',
                uid
              ]
            );
            migratedCount++;
            logger.info(`   Migrated store: ${storeData.storeName}`);
          } else {
            logger.warn(`  ⚠️ Store user not found, skipping: ${storeData.storeName}`);
          }
        } else {
          skippedCount++;
          logger.info(`  ⏭️ Store already exists for owner: ${uid}`);
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error migrating store ${uid}:`, err.message);
      }
    }

    logger.info(` Stores migration complete: ${migratedCount} added, ${skippedCount} skipped`);
    return { migratedCount, skippedCount };
  } catch (error) {
    logger.error('❌ Error in migrateStores:', error);
    throw error;
  }
}

async function migrateProducts() {
  logger.info(' Starting to migrate products from Firebase...');
  try {
    const productsSnapshot = await db.collection('products').get();
    let migratedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;

    for (const doc of productsSnapshot.docs) {
      const productData = doc.data();
      const productId = doc.id;

      try {
        const connection = await pool.getConnection();

        // Find store by store owner email
        const storeEmail = productData.storeOwnerEmail || '';
        const [store] = await connection.execute(
          `SELECT stores.id FROM stores
           JOIN users ON stores.owner_uid = users.uid
           WHERE users.email = ?`,
          [storeEmail]
        );

        if (store.length > 0) {
          const storeId = store[0].id;

          // Check if product already exists
          const [existingProduct] = await connection.execute(
            'SELECT id FROM products WHERE name = ? AND store_id = ?',
            [productData.name || '', storeId]
          );

          if (existingProduct.length === 0) {
            await connection.execute(
              `INSERT INTO products (name, description, price, store_id, image_url, is_active, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
              [
                productData.name || '',
                productData.description || '',
                parseFloat(productData.price) || 0,
                storeId,
                productData.imageUrl || '',
                productData.approved !== false
              ]
            );
            migratedCount++;
            logger.info(`   Migrated product: ${productData.name}`);
          } else {
            skippedCount++;
            logger.info(`  ⏭️ Product already exists: ${productData.name}`);
          }
        } else {
          logger.warn(`  ⚠️ Store not found for product ${productData.name}, skipping`);
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error migrating product ${productId}:`, err.message);
        errorCount++;
      }
    }

    logger.info(` Products migration complete: ${migratedCount} added, ${skippedCount} skipped, ${errorCount} errors`);
    return { migratedCount, skippedCount, errorCount };
  } catch (error) {
    logger.error('❌ Error in migrateProducts:', error);
    throw error;
  }
}

async function migrateDeliveryPeople() {
  logger.info(' Starting to migrate delivery people from Firebase...');
  try {
    const deliverySnapshot = await db.collection('deliveryPersonRequests').get();
    let migratedCount = 0;
    let skippedCount = 0;

    for (const doc of deliverySnapshot.docs) {
      const deliveryData = doc.data();
      const uid = doc.id;

      try {
        const connection = await pool.getConnection();

        // Check if delivery person already exists
        const [existingDelivery] = await connection.execute(
          'SELECT id FROM users WHERE uid = ?',
          [uid]
        );

        if (existingDelivery.length === 0) {
          // Insert as user first (if not exists)
          await connection.execute(
            `INSERT INTO users (uid, email, display_name, phone, created_at, updated_at)
             VALUES (?, ?, ?, ?, NOW(), NOW())`,
            [
              uid,
              deliveryData.email || '',
              deliveryData.fullName || '',
              deliveryData.phoneNumber || ''
            ]
          );
          migratedCount++;
          logger.info(`   Migrated delivery person: ${deliveryData.fullName}`);
        } else {
          skippedCount++;
          logger.info(`  ⏭️ Delivery person already exists: ${deliveryData.email}`);
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error migrating delivery person ${uid}:`, err.message);
      }
    }

    logger.info(` Delivery people migration complete: ${migratedCount} added, ${skippedCount} skipped`);
    return { migratedCount, skippedCount };
  } catch (error) {
    logger.error('❌ Error in migrateDeliveryPeople:', error);
    throw error;
  }
}

async function runMigration() {
  try {
    logger.info('Starting Firebase to MySQL migration...\n');

    const usersResult = await migrateUsers();
    logger.info('');
    
    const storesResult = await migrateStores();
    logger.info('');
    
    const productsResult = await migrateProducts();
    logger.info('');
    
    const deliveryResult = await migrateDeliveryPeople();
    logger.info('');

    logger.info('=' * 50);
    logger.info(' Migration Summary:');
    logger.info(`  Users: ${usersResult.migratedCount} added, ${usersResult.skippedCount} skipped`);
    logger.info(`  Stores: ${storesResult.migratedCount} added, ${storesResult.skippedCount} skipped`);
    logger.info(`  Products: ${productsResult.migratedCount} added, ${productsResult.skippedCount} skipped`);
    logger.info(`  Delivery People: ${deliveryResult.migratedCount} added, ${deliveryResult.skippedCount} skipped`);
    logger.info('=' * 50);
    logger.info(' Migration completed successfully!\n');

    process.exit(0);
  } catch (error) {
    logger.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run migration
runMigration();
