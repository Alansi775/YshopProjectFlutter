import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

/**
 * Migration: Add 'status' column to products table
 * Tracks product approval status: pending, approved, rejected
 */
export async function up() {
  const connection = await pool.getConnection();
  try {
    // Check if column already exists
    const [columns] = await connection.execute(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'products' AND COLUMN_NAME = 'status'"
    );

    if (columns.length > 0) {
      logger.info(' status column already exists in products table');
      connection.release();
      return;
    }

    // Add status column
    await connection.execute(`
      ALTER TABLE products 
      ADD COLUMN status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending'
      AFTER is_active
    `);

    // Add index for status
    await connection.execute(`
      ALTER TABLE products 
      ADD INDEX idx_status (status)
    `);

    logger.info(' Added status column to products table');
    connection.release();
  } catch (error) {
    logger.error('❌ Migration failed:', error);
    connection.release();
    throw error;
  }
}

export async function down() {
  const connection = await pool.getConnection();
  try {
    await connection.execute(`
      ALTER TABLE products 
      DROP COLUMN IF EXISTS status
    `);
    logger.info(' Rolled back status column from products table');
    connection.release();
  } catch (error) {
    logger.error('❌ Rollback failed:', error);
    connection.release();
    throw error;
  }
}
