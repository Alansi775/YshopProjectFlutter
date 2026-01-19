import pool from '../config/database.js';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
dotenv.config();

const JWT_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || 'change_this_secret';
const JWT_EXPIRES_IN = process.env.ADMIN_JWT_EXPIRES_IN || '8h';

export async function login(req, res, next) {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ success: false, message: 'Missing credentials' });
  try {
    const conn = await pool.getConnection();
    const [rows] = await conn.execute('SELECT id, email, password_hash, role, first_name, last_name FROM yshopadmins WHERE email = ?', [email]);
    conn.release();
    if (!rows || rows.length === 0) return res.status(401).json({ success: false, message: 'Invalid credentials' });
    const admin = rows[0];
    const ok = await bcrypt.compare(password, admin.password_hash);
    if (!ok) return res.status(401).json({ success: false, message: 'Invalid credentials' });

    const payload = { id: admin.id, email: admin.email, role: admin.role };
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

    return res.json({ success: true, data: { id: admin.id, email: admin.email, role: admin.role, first_name: admin.first_name, last_name: admin.last_name }, token });
  } catch (err) {
    next(err);
  }
}

export default { login };
