import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

async function up() {
  const connection = await pool.getConnection();
  try {
    // Add payment_method and delivery_option if not exists
    await connection.execute(`
      ALTER TABLE orders
      ADD COLUMN IF NOT EXISTS payment_method VARCHAR(255) NULL,
      ADD COLUMN IF NOT EXISTS delivery_option VARCHAR(255) NULL;
    `);
    logger.info('Migration add_order_fields applied');
  } catch (e) {
    logger.error('Migration add_order_fields failed:', e);
    throw e;
  } finally {
    connection.release();
  }
}

up().then(()=> process.exit(0)).catch(()=> process.exit(1));
