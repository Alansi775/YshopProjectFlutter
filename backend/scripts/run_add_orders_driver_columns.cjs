const mysql = require('mysql2/promise');
const fs = require('fs');
require('dotenv').config();

(async function(){
  const host = process.env.DB_HOST || '127.0.0.1';
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || '';
  const database = process.env.DB_NAME || process.env.DB_DATABASE || 'yshop_db';
  const port = process.env.DB_PORT ? parseInt(process.env.DB_PORT,10) : 3306;

  const conn = await mysql.createConnection({
    host,
    user,
    password,
    database,
    port,
  });

  try {
    const [rows] = await conn.execute("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'orders'", [cfg.database]);
    const cols = rows.map(r => r.COLUMN_NAME);
    if (!cols.includes('driver_id')) {
      await conn.execute("ALTER TABLE orders ADD COLUMN driver_id VARCHAR(255) DEFAULT NULL");
      console.log('Added orders.driver_id');
    } else {
      console.log('orders.driver_id already exists');
    }

    if (!cols.includes('driver_location')) {
      await conn.execute("ALTER TABLE orders ADD COLUMN driver_location JSON DEFAULT NULL");
      console.log('Added orders.driver_location');
    } else {
      console.log('orders.driver_location already exists');
    }
  } catch (e) {
    console.error('Migration failed', e.message);
    process.exit(2);
  } finally {
    await conn.end();
  }

  console.log('Migration completed');
  process.exit(0);
})();
