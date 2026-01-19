import pool from '../config/database.js';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
dotenv.config();

const JWT_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || 'change_this_secret';
const JWT_EXPIRES_IN = process.env.ADMIN_JWT_EXPIRES_IN || '8h';

export async function staffLogin(req, res, next) {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ success: false, message: 'Missing credentials' });
  try {
    const conn = await pool.getConnection();
    const [rows] = await conn.execute('SELECT id, email, password_hash, role, admin_id, first_name, last_name, status, is_banned FROM yshopusers WHERE email = ?', [email]);
    conn.release();
    if (!rows || rows.length === 0) return res.status(401).json({ success: false, message: 'Invalid credentials' });
    const user = rows[0];

    // Check ban/status
    if (user.is_banned == 1 || (user.status && String(user.status).toLowerCase() === 'banned')) {
      return res.status(403).json({ success: false, message: 'User is banned' });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ success: false, message: 'Invalid credentials' });

    const payload = { id: user.id, email: user.email, role: user.role, admin_id: user.admin_id };
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

    return res.json({ success: true, data: { id: user.id, email: user.email, role: user.role, first_name: user.first_name, last_name: user.last_name, admin_id: user.admin_id }, token });
  } catch (err) {
    next(err);
  }
}

export default { staffLogin };
