#!/usr/bin/env node
import pool from '../src/config/database.js';

const email = process.argv[2] || 'user@example.com';

async function run() {
  try {
    const [admins] = await pool.execute('SELECT id,email,role,status,is_banned,CHAR_LENGTH(password_hash)>0 AS has_password FROM yshopadmins WHERE email = ? LIMIT 1', [email]);
    const [users] = await pool.execute('SELECT id,email,admin_id,status,is_banned FROM yshopusers WHERE email = ? LIMIT 1', [email]);

    console.log('ADMIN:', JSON.stringify(admins[0] || null, null, 2));
    console.log('USER :', JSON.stringify(users[0] || null, null, 2));

    await pool.end();
    process.exit(0);
  } catch (err) {
    console.error('ERROR', err);
    try { await pool.end(); } catch(_){}
    process.exit(1);
  }
}

run();
