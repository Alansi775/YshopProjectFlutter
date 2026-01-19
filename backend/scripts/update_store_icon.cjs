#!/usr/bin/env node
import pool from '../src/config/database.js';

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node update_store_icon.cjs <storeId> <relativePath>');
    process.exit(1);
  }
  const storeId = args[0];
  const relativePath = args[1];

  try {
    const [result] = await pool.query('UPDATE stores SET icon_url = ? WHERE id = ?', [relativePath, storeId]);
    console.log('Update result:', result.affectedRows, 'rows affected');
    process.exit(0);
  } catch (e) {
    console.error('Failed to update store icon:', e.message);
    process.exit(2);
  }
}

main();
