#!/usr/bin/env node
// Safe migration runner: adds status and is_banned to yshopusers if missing
import pool from '../src/config/database.js';
import logger from '../src/config/logger.js';

async function columnExists(table, column) {
  const [rows] = await pool.execute(
    `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [table, column]
  );
  return rows.length > 0;
}

async function run() {
  try {
    const table = 'yshopusers';
    const hasStatus = await columnExists(table, 'status');
    const hasIsBanned = await columnExists(table, 'is_banned');

    if (!hasStatus) {
      logger.info('Adding column `status` to yshopusers');
      await pool.execute(`ALTER TABLE ${table} ADD COLUMN status VARCHAR(32) DEFAULT 'active' AFTER role`);
    } else {
      logger.info('Column `status` already exists');
    }

    if (!hasIsBanned) {
      logger.info('Adding column `is_banned` to yshopusers');
      await pool.execute(`ALTER TABLE ${table} ADD COLUMN is_banned TINYINT(1) DEFAULT 0 AFTER status`);
    } else {
      logger.info('Column `is_banned` already exists');
    }

    logger.info('Migration completed');
    process.exit(0);
  } catch (err) {
    logger.error('Migration failed', err);
    process.exit(1);
  }
}

run();
