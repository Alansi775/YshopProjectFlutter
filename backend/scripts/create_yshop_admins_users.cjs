#!/usr/bin/env node
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

async function main() {
  const host = process.env.DB_HOST || '127.0.0.1';
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || '';
  const database = process.env.DB_NAME || 'yshop_db';

  const conn = await mysql.createConnection({ host, user, password, database });
  try {
    console.log('Connected, creating tables if not exists...');

    const createAdmins = `
      CREATE TABLE IF NOT EXISTS yshopadmins (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        role ENUM('superadmin','admin') NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `;

    const createUsers = `
      CREATE TABLE IF NOT EXISTS yshopusers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        admin_id INT NULL,
        role ENUM('user') DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (admin_id) REFERENCES yshopadmins(id) ON DELETE SET NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `;

    await conn.execute(createAdmins);
    console.log('Ensured table `yshopadmins` exists.');
    await conn.execute(createUsers);
    console.log('Ensured table `yshopusers` exists.');

    // Seed superadmin if not exists
    const superEmail = process.env.SUPERADMIN_EMAIL || 'mohammed.alansi@yshop.com';
    const superPassword = process.env.SUPERADMIN_PASSWORD || 'Alansi77';

    const [rows] = await conn.execute('SELECT id FROM yshopadmins WHERE email = ?', [superEmail]);
    if (rows.length === 0) {
      const hash = await bcrypt.hash(superPassword, 10);
      await conn.execute(
        'INSERT INTO yshopadmins (email, password_hash, role, first_name, last_name) VALUES (?, ?, ?, ?, ?)',
        [superEmail, hash, 'superadmin', 'Mohammed', 'Alansi']
      );
      console.log('Inserted superadmin:', superEmail);
    } else {
      console.log('Superadmin already exists:', superEmail);
    }

    console.log('Migration completed.');
  } catch (err) {
    console.error('Error running migration:', err);
    process.exitCode = 1;
  } finally {
    await conn.end();
  }
}

main();
