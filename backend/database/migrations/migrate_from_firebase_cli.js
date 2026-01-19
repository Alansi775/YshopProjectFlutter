#!/usr/bin/env node

/**
 * Firebase to MySQL Migration using Google Cloud Credentials
 * استخدم: npm run migrate:firebase
 */

import admin from 'firebase-admin';
import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';
import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import os from 'os';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Get Google Cloud credentials from firebase CLI cache
function getFirebaseCredentials() {
  const credentialsPaths = [
    path.join(os.homedir(), '.config/firebase/credentials.json'),
    path.join(os.homedir(), '.firebase/credentials.json'),
  ];

  for (const credPath of credentialsPaths) {
    if (fs.existsSync(credPath)) {
      logger.info(` Found Firebase credentials at: ${credPath}`);
      return JSON.parse(fs.readFileSync(credPath, 'utf8'));
    }
  }

  return null;
}

// Initialize Firebase with default credentials (from gcloud CLI)
async function initializeFirebase() {
  try {
    // Try to use Application Default Credentials
    process.env.GOOGLE_APPLICATION_CREDENTIALS = path.join(
      os.homedir(),
      '.config/gcloud/application_default_credentials.json'
    );

    if (!admin.apps.length) {
      admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'home-720ef',
      });
    }

    logger.info(' Firebase initialized with Application Default Credentials');
    return admin.firestore();
  } catch (error) {
    logger.error('❌ Firebase initialization failed:', error.message);
    logger.info('Make sure you are logged in: firebase login');
    throw error;
  }
}

async function migrateUsers(db) {
  logger.info('\n Starting to migrate users from Firebase...');
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
          await connection.execute(
            `INSERT INTO users (uid, email, display_name, phone, created_at, updated_at)
             VALUES (?, ?, ?, ?, NOW(), NOW())`,
            [
              uid,
              userData.email || '',
              userData.displayName || userData.name || '',
              userData.phone || ''
            ]
          );
          migratedCount++;
          logger.info(`   User: ${userData.email || uid}`);
        } else {
          skippedCount++;
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error with user ${uid}:`, err.message);
      }
    }

    logger.info(`\n Users: ${migratedCount} added, ${skippedCount} skipped`);
    return { migratedCount, skippedCount };
  } catch (error) {
    logger.error('❌ Error in migrateUsers:', error);
    throw error;
  }
}

async function migrateStores(db) {
  logger.info('\n Starting to migrate stores from Firebase...');
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
          // Verify user exists
          const [user] = await connection.execute(
            'SELECT id FROM users WHERE uid = ?',
            [uid]
          );

          if (user.length > 0) {
            await connection.execute(
              `INSERT INTO stores (name, description, phone, address, latitude, longitude, icon_url, owner_uid, is_active, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, true, NOW(), NOW())`,
              [
                storeData.storeName || 'متجر بدون اسم',
                storeData.description || '',
                storeData.phoneNumber || '',
                storeData.address || '',
                parseFloat(storeData.latitude) || 0,
                parseFloat(storeData.longitude) || 0,
                storeData.storeIconUrl || '',
                uid
              ]
            );
            migratedCount++;
            logger.info(`   Store: ${storeData.storeName || 'متجر'}`);
          }
        } else {
          skippedCount++;
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error with store ${uid}:`, err.message);
      }
    }

    logger.info(`\n Stores: ${migratedCount} added, ${skippedCount} skipped`);
    return { migratedCount, skippedCount };
  } catch (error) {
    logger.error('❌ Error in migrateStores:', error);
    throw error;
  }
}

async function migrateProducts(db) {
  logger.info('\n Starting to migrate products from Firebase...');
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

        // Find store by owner email
        const storeEmail = productData.storeOwnerEmail || '';
        const [storeResult] = await connection.execute(
          `SELECT stores.id FROM stores
           JOIN users ON stores.owner_uid = users.uid
           WHERE users.email = ?`,
          [storeEmail]
        );

        if (storeResult.length > 0) {
          const storeId = storeResult[0].id;

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
                productData.name || 'منتج بدون اسم',
                productData.description || '',
                parseFloat(productData.price) || 0,
                storeId,
                productData.imageUrl || '',
                productData.approved !== false
              ]
            );
            migratedCount++;
            logger.info(`   Product: ${productData.name || 'منتج'}`);
          } else {
            skippedCount++;
          }
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error with product ${productId}:`, err.message);
        errorCount++;
      }
    }

    logger.info(`\n Products: ${migratedCount} added, ${skippedCount} skipped, ${errorCount} errors`);
    return { migratedCount, skippedCount, errorCount };
  } catch (error) {
    logger.error('❌ Error in migrateProducts:', error);
    throw error;
  }
}

async function migrateCategories(db) {
  logger.info('\n Starting to migrate categories from Firebase...');
  try {
    const categoriesSnapshot = await db.collection('categories').get();
    let migratedCount = 0;
    let skippedCount = 0;

    for (const doc of categoriesSnapshot.docs) {
      const categoryData = doc.data();

      try {
        const connection = await pool.getConnection();

        const [existing] = await connection.execute(
          'SELECT id FROM categories WHERE name = ?',
          [categoryData.name || '']
        );

        if (existing.length === 0) {
          await connection.execute(
            'INSERT INTO categories (name, created_at) VALUES (?, NOW())',
            [categoryData.name || 'فئة بدون اسم']
          );
          migratedCount++;
          logger.info(`   Category: ${categoryData.name}`);
        } else {
          skippedCount++;
        }

        connection.release();
      } catch (err) {
        logger.error(`  ❌ Error with category:`, err.message);
      }
    }

    logger.info(`\n Categories: ${migratedCount} added, ${skippedCount} skipped`);
    return { migratedCount, skippedCount };
  } catch (error) {
    logger.error('❌ Error in migrateCategories:', error);
    throw error;
  }
}

async function runMigration() {
  let db;
  try {
    logger.info('Starting Firebase → MySQL Migration\n');
    logger.info('=====================================\n');

    db = await initializeFirebase();

    const results = {
      users: await migrateUsers(db),
      stores: await migrateStores(db),
      products: await migrateProducts(db),
      categories: await migrateCategories(db),
    };

    logger.info('\n=====================================');
    logger.info(' MIGRATION COMPLETE!\n');
    logger.info('Summary:');
    logger.info(`  👥 Users: ${results.users.migratedCount} added`);
    logger.info(`   Stores: ${results.stores.migratedCount} added`);
    logger.info(`   Products: ${results.products.migratedCount} added`);
    logger.info(`  📂 Categories: ${results.categories.migratedCount} added`);
    logger.info('=====================================\n');

    process.exit(0);
  } catch (error) {
    logger.error('❌ Migration failed:', error.message);
    logger.info('\nTroubleshooting:');
    logger.info('1. Make sure you are logged into Firebase CLI:');
    logger.info('   firebase login');
    logger.info('2. Select your project:');
    logger.info('   firebase use --add');
    logger.info('3. Run the migration again');
    process.exit(1);
  }
}

// Run migration
runMigration();
