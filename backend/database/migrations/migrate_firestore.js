#!/usr/bin/env node

/**
 * Firebase to MySQL Migration using Firestore REST API + Web API Key
 * This uses the public API key from google-services.json
 */

import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';
import fetch from 'node-fetch';

const PROJECT_ID = 'home-720ef';
const API_KEY = 'AIzaSyDh3YAaUFyTwZLqhlcrCH5f5BtT4hDpWMs';
const FIRESTORE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function fetchFirestoreCollection(collectionName) {
  const url = `${FIRESTORE_URL}/${collectionName}?key=${API_KEY}`;
  logger.info(`  📡 Fetching: ${collectionName}`);

  try {
    const response = await fetch(url);

    if (!response.ok) {
      const error = await response.text();
      logger.error(`    API Response: ${response.status}`, error);
      throw new Error(`API Error: ${response.status}`);
    }

    const data = await response.json();
    return data.documents || [];
  } catch (error) {
    logger.error(`    Error: ${error.message}`);
    throw error;
  }
}

function parseFirestoreValue(value) {
  if (value.stringValue) return value.stringValue;
  if (value.integerValue) return parseInt(value.integerValue);
  if (value.doubleValue) return parseFloat(value.doubleValue);
  if (value.booleanValue) return value.booleanValue;
  if (value.timestampValue) return new Date(value.timestampValue);
  if (value.arrayValue) return value.arrayValue.values || [];
  if (value.nullValue) return null;
  return value;
}

function parseFirestoreDocument(doc) {
  const result = {};
  if (doc.fields) {
    Object.entries(doc.fields).forEach(([key, fieldValue]) => {
      result[key] = parseFirestoreValue(fieldValue);
    });
  }
  return result;
}

async function migrateUsers(users) {
  logger.info('\n Migrating users...');
  let migratedCount = 0;
  let skippedCount = 0;

  for (const doc of users) {
    const userData = parseFirestoreDocument(doc);
    const uid = doc.name.split('/').pop();

    try {
      const connection = await pool.getConnection();

      const [existing] = await connection.execute(
        'SELECT id FROM users WHERE uid = ?',
        [uid]
      );

      if (existing.length === 0) {
        await connection.execute(
          `INSERT INTO users (uid, email, display_name, phone, created_at, updated_at)
           VALUES (?, ?, ?, ?, NOW(), NOW())`,
          [uid, userData.email || '', userData.displayName || userData.name || '', userData.phone || '']
        );
        migratedCount++;
        logger.info(`   ${userData.email || uid.substring(0, 8)}`);
      } else {
        skippedCount++;
      }

      connection.release();
    } catch (err) {
      logger.error(`  ❌ Error: ${err.message}`);
    }
  }

  logger.info(`\n Users: ${migratedCount} added, ${skippedCount} skipped`);
  return { migratedCount, skippedCount };
}

async function migrateStores(stores) {
  logger.info('\n Migrating stores...');
  let migratedCount = 0;
  let skippedCount = 0;

  for (const doc of stores) {
    const storeData = parseFirestoreDocument(doc);
    const uid = doc.name.split('/').pop();

    try {
      const connection = await pool.getConnection();

      const [existing] = await connection.execute(
        'SELECT id FROM stores WHERE owner_uid = ?',
        [uid]
      );

      if (existing.length === 0) {
        const [user] = await connection.execute(
          'SELECT id FROM users WHERE uid = ?',
          [uid]
        );

        if (user.length > 0) {
          await connection.execute(
            `INSERT INTO stores (name, description, phone, address, latitude, longitude, icon_url, owner_uid, is_active, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, true, NOW(), NOW())`,
            [
              storeData.storeName || 'متجر',
              storeData.description || '',
              storeData.phoneNumber || '',
              storeData.address || '',
              parseFloat(storeData.latitude) || 0,
              parseFloat(storeData.longitude) || 0,
              storeData.storeIconUrl || '',
              uid,
            ]
          );
          migratedCount++;
          logger.info(`   ${storeData.storeName}`);
        }
      } else {
        skippedCount++;
      }

      connection.release();
    } catch (err) {
      logger.error(`  ❌ Error: ${err.message}`);
    }
  }

  logger.info(`\n Stores: ${migratedCount} added, ${skippedCount} skipped`);
  return { migratedCount, skippedCount };
}

async function migrateProducts(products) {
  logger.info('\n Migrating products...');
  let migratedCount = 0;
  let skippedCount = 0;

  for (const doc of products) {
    const productData = parseFirestoreDocument(doc);

    try {
      const connection = await pool.getConnection();

      const storeEmail = productData.storeOwnerEmail || '';
      const [storeResult] = await connection.execute(
        `SELECT stores.id FROM stores
         JOIN users ON stores.owner_uid = users.uid
         WHERE users.email = ?`,
        [storeEmail]
      );

      if (storeResult.length > 0) {
        const storeId = storeResult[0].id;

        const [existing] = await connection.execute(
          'SELECT id FROM products WHERE name = ? AND store_id = ?',
          [productData.name || '', storeId]
        );

        if (existing.length === 0) {
          await connection.execute(
            `INSERT INTO products (name, description, price, store_id, image_url, is_active, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
            [
              productData.name || 'منتج',
              productData.description || '',
              parseFloat(productData.price) || 0,
              storeId,
              productData.imageUrl || '',
              productData.approved !== false,
            ]
          );
          migratedCount++;
          logger.info(`   ${productData.name}`);
        } else {
          skippedCount++;
        }
      }

      connection.release();
    } catch (err) {
      logger.error(`  ❌ Error: ${err.message}`);
    }
  }

  logger.info(`\n Products: ${migratedCount} added, ${skippedCount} skipped`);
  return { migratedCount, skippedCount };
}

async function runMigration() {
  try {
    logger.info('\nFirebase → MySQL Migration\n');
    logger.info('=====================================\n');

    logger.info('📡 Fetching data from Firestore...\n');
    const users = await fetchFirestoreCollection('users');
    const stores = await fetchFirestoreCollection('storeRequests');
    const products = await fetchFirestoreCollection('products');

    logger.info(`\n  Found: ${users.length} users, ${stores.length} stores, ${products.length} products\n`);

    const results = {
      users: await migrateUsers(users),
      stores: await migrateStores(stores),
      products: await migrateProducts(products),
    };

    logger.info('\n=====================================');
    logger.info(' MIGRATION COMPLETE!\n');
    logger.info('Summary:');
    logger.info(`  👥 Users: ${results.users.migratedCount} added`);
    logger.info(`   Stores: ${results.stores.migratedCount} added`);
    logger.info(`   Products: ${results.products.migratedCount} added`);
    logger.info('=====================================\n');

    process.exit(0);
  } catch (error) {
    logger.error('\n❌ Migration failed:', error.message);
    process.exit(1);
  }
}

// Run
runMigration();
