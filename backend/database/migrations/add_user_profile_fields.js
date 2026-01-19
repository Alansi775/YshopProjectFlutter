import pool from '../../src/config/database.js';
import logger from '../../src/config/logger.js';

async function up() {
  let connection;
  try {
    connection = await pool.getConnection();
    logger.info('Running migration: add_user_profile_fields');

    // Add columns individually if they don't exist (safer across MySQL versions)
    const columnsToAdd = [
      { name: 'surname', sql: 'VARCHAR(255)' },
      { name: 'national_id', sql: 'VARCHAR(100)' },
      { name: 'latitude', sql: 'DECIMAL(10,8)' },
      { name: 'longitude', sql: 'DECIMAL(11,8)' },
      { name: 'building_info', sql: 'TEXT' },
      { name: 'apartment_number', sql: 'VARCHAR(100)' },
      { name: 'delivery_instructions', sql: 'TEXT' },
    ];

    for (const col of columnsToAdd) {
      const [rows] = await connection.execute(
        `SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = ?`,
        [col.name]
      );
      const exists = rows[0].cnt > 0;
      if (!exists) {
        await connection.execute(`ALTER TABLE users ADD COLUMN ${col.name} ${col.sql}`);
        logger.info(`Added column ${col.name}`);
      } else {
        logger.info(`Column ${col.name} already exists, skipping`);
      }
    }

    logger.info('Migration add_user_profile_fields completed');
    connection.release();
  } catch (err) {
    logger.error('Migration add_user_profile_fields failed:', err);
    if (connection) connection.release();
    throw err;
  }
}

up().then(() => process.exit(0)).catch(() => process.exit(1));
