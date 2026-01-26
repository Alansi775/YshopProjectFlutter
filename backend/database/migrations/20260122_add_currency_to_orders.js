import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

async function up() {
  const connection = await pool.getConnection();
  try {
    // Check if currency column already exists
    const [currencyRows] = await connection.execute(
      `SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'orders' AND COLUMN_NAME = 'currency'`
    );
    const currencyExists = currencyRows[0] && currencyRows[0].cnt > 0;

    if (!currencyExists) {
      await connection.execute(`ALTER TABLE orders ADD COLUMN currency VARCHAR(10) DEFAULT 'USD' NULL`);
      logger.info('Added column orders.currency');
    } else {
      logger.info('Column orders.currency already exists');
    }

    logger.info('Migration 20260122_add_currency_to_orders applied');
  } catch (e) {
    logger.error('Migration 20260122_add_currency_to_orders failed:', e);
    throw e;
  } finally {
    connection.release();
  }
}

up().then(() => process.exit(0)).catch(() => process.exit(1));
