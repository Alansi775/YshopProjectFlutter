import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

/**
 * Migration: Add owner_uid to stores table
 */

async function migrate() {
  let connection;
  try {
    connection = await pool.getConnection();

    logger.info('Running migration: add_store_owner...');

    // Check if owner_uid column exists
    const [columns] = await connection.execute(`
      SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_NAME = 'stores' AND COLUMN_NAME = 'owner_uid'
    `);

    if (columns.length === 0) {
      // Add owner_uid column
      await connection.execute(`
        ALTER TABLE stores ADD COLUMN owner_uid VARCHAR(255) AFTER is_active
      `);
      logger.info(' Added owner_uid column to stores table');

      // Add foreign key
      await connection.execute(`
        ALTER TABLE stores ADD INDEX idx_owner_uid (owner_uid)
      `);
      logger.info(' Added index on owner_uid');

      // Add foreign key constraint
      await connection.execute(`
        ALTER TABLE stores ADD CONSTRAINT fk_stores_owner_uid 
        FOREIGN KEY (owner_uid) REFERENCES users(uid) ON DELETE SET NULL
      `);
      logger.info(' Added foreign key constraint');
    } else {
      logger.info(' owner_uid column already exists');
    }

    logger.info(' Migration completed successfully');
  } catch (error) {
    logger.error('❌ Migration failed:', error);
    throw error;
  } finally {
    if (connection) {
      connection.release();
    }
  }
}

// Run migration
migrate().catch(err => {
  console.error('Migration error:', err);
  process.exit(1);
});
