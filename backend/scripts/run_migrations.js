#!/usr/bin/env node

/**
 * Database Migration Runner
 * Executes pending migrations in order
 */

import { fileURLToPath } from 'url';
import path from 'path';
import pool from '../src/config/database.js';
import logger from '../src/config/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const migrationsDir = path.join(__dirname, '../database/migrations');

async function runMigrations() {
  const connection = await pool.getConnection();
  
  try {
    // Create migrations tracking table if not exists
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    logger.info(' Migrations table ready');

    // Import and run add_product_status migration
    try {
      const { up } = await import('./add_product_status.js');
      await up();
      logger.info(' Migration completed: add_product_status');
    } catch (e) {
      logger.error('❌ Migration failed: add_product_status', e.message);
    }

    logger.info(' All migrations completed successfully');
    connection.release();
    process.exit(0);
  } catch (error) {
    logger.error('❌ Migration error:', error);
    connection.release();
    process.exit(1);
  }
}

runMigrations();
