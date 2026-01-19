import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

async function up() {
  const connection = await pool.getConnection();
  try {
    // Safer approach: check information_schema for each column then add if missing
    const [driverIdRows] = await connection.execute(
      `SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'orders' AND COLUMN_NAME = 'driver_id'`
    );
    const driverIdExists = driverIdRows[0] && driverIdRows[0].cnt > 0;

    if (!driverIdExists) {
      await connection.execute(`ALTER TABLE orders ADD COLUMN driver_id VARCHAR(255) NULL`);
      logger.info('Added column orders.driver_id');
    } else {
      logger.info('Column orders.driver_id already exists');
    }

    const [driverLocRows] = await connection.execute(
      `SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'orders' AND COLUMN_NAME = 'driver_location'`
    );
    const driverLocExists = driverLocRows[0] && driverLocRows[0].cnt > 0;

    if (!driverLocExists) {
      await connection.execute(`ALTER TABLE orders ADD COLUMN driver_location TEXT NULL`);
      logger.info('Added column orders.driver_location');
    } else {
      logger.info('Column orders.driver_location already exists');
    }

    logger.info('Migration 20251229_add_driver_columns_to_orders applied');
  } catch (e) {
    logger.error('Migration 20251229_add_driver_columns_to_orders failed:', e);
    throw e;
  } finally {
    connection.release();
  }
}

up().then(() => process.exit(0)).catch(() => process.exit(1));
