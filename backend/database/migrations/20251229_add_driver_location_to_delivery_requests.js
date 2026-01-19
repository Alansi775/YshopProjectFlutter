import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

async function up() {
  const connection = await pool.getConnection();
  try {
    const [latRows] = await connection.execute(
      `SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_requests' AND COLUMN_NAME = 'latitude'`
    );
    const latExists = latRows[0] && latRows[0].cnt > 0;

    if (!latExists) {
      await connection.execute(`ALTER TABLE delivery_requests ADD COLUMN latitude DECIMAL(10,8) NULL`);
      logger.info('Added column delivery_requests.latitude');
    } else {
      logger.info('Column delivery_requests.latitude already exists');
    }

    const [lngRows] = await connection.execute(
      `SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_requests' AND COLUMN_NAME = 'longitude'`
    );
    const lngExists = lngRows[0] && lngRows[0].cnt > 0;

    if (!lngExists) {
      await connection.execute(`ALTER TABLE delivery_requests ADD COLUMN longitude DECIMAL(11,8) NULL`);
      logger.info('Added column delivery_requests.longitude');
    } else {
      logger.info('Column delivery_requests.longitude already exists');
    }

    logger.info('Migration 20251229_add_driver_location_to_delivery_requests applied');
  } catch (e) {
    logger.error('Migration 20251229_add_driver_location_to_delivery_requests failed:', e);
    throw e;
  } finally {
    connection.release();
  }
}

up().then(() => process.exit(0)).catch(() => process.exit(1));
