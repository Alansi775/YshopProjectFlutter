import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

/**
 * Migration: Add status column to stores table (optional, we already use is_active)
 */

async function migrate() {
  let connection;
  try {
    connection = await pool.getConnection();

    logger.info('Running migration: add_store_status...');

    // Check if status column exists
    const [columns] = await connection.execute(`
      SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_NAME = 'stores' AND COLUMN_NAME = 'status'
    `);

    if (columns.length === 0) {
      // Add status column
      await connection.execute(`
        ALTER TABLE stores ADD COLUMN status VARCHAR(50) DEFAULT 'pending'
      `);
      logger.info(' Added status column to stores table');

      // Sync status with is_active
      await connection.execute(`
        UPDATE stores SET status = CASE WHEN is_active = true THEN 'approved' ELSE 'pending' END
      `);
      logger.info(' Synced status values with is_active');
    } else {
      logger.info(' status column already exists');
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
