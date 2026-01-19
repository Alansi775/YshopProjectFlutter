import pool from '../config/database.js';
import bcrypt from 'bcryptjs';

export async function listAdmins(req, res, next) {
  try {
    const [rows] = await pool.execute('SELECT id, email, first_name, last_name, role, created_at FROM yshopadmins ORDER BY id DESC');
    return res.json({ success: true, data: rows });
  } catch (err) {
    next(err);
  }
}

export async function createAdmin(req, res, next) {
  const { email, password, first_name, last_name, role } = req.body || {};
  if (!email || !password || !role) return res.status(400).json({ success: false, message: 'Missing fields' });
  try {
    const hash = await bcrypt.hash(password, 10);
    const [result] = await pool.execute('INSERT INTO yshopadmins (email, password_hash, first_name, last_name, role) VALUES (?, ?, ?, ?, ?)', [email, hash, first_name || null, last_name || null, role]);
    const id = result.insertId;
    return res.json({ success: true, data: { id, email, first_name, last_name, role } });
  } catch (err) {
    if (err && err.code === 'ER_DUP_ENTRY') return res.status(409).json({ success: false, message: 'Admin already exists' });
    next(err);
  }
}

export async function listUsersForAdmin(req, res, next) {
  const adminId = req.params.adminId;
  try {
    const [rows] = await pool.execute('SELECT id, email, first_name, last_name, role, created_at FROM yshopusers WHERE admin_id = ?', [adminId]);
    return res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

export async function createUserUnderAdmin(req, res, next) {
  const adminId = req.params.adminId;
  const { first_name, last_name, password } = req.body || {};
  if (!first_name || !last_name || !password) return res.status(400).json({ success: false, message: 'Missing fields' });
  try {
    // generate email first.last@yshop.com (lowercase, dots)
    const local = `${first_name.trim().toLowerCase()}.${last_name.trim().toLowerCase()}`.replace(/\s+/g, '.');
    let email = `${local}@yshop.com`;
    // ensure uniqueness
    let suffix = 1;
    while (true) {
      const [rows] = await pool.execute('SELECT id FROM yshopusers WHERE email = ?', [email]);
      if (rows.length === 0) break;
      email = `${local}${suffix}@yshop.com`;
      suffix++;
    }

    const hash = await bcrypt.hash(password, 10);
    const [result] = await pool.execute('INSERT INTO yshopusers (email, password_hash, first_name, last_name, admin_id, role) VALUES (?, ?, ?, ?, ?, ?)', [email, hash, first_name, last_name, adminId, 'user']);
    const id = result.insertId;
    return res.json({ success: true, data: { id, email, first_name, last_name } });
  } catch (err) { next(err); }
}

export async function updateAdminStatus(req, res, next) {
  try {
    const targetId = req.params.adminId;
    const { status, is_banned } = req.body || {};

    const caller = req.admin;
    if (!caller || caller.role !== 'superadmin') return res.status(403).json({ success: false, message: 'Forbidden: superadmin required' });

    const [rows] = await pool.execute('SELECT id, role FROM yshopadmins WHERE id = ?', [targetId]);
    if (!rows || rows.length === 0) return res.status(404).json({ success: false, message: 'Admin not found' });

    if (status !== undefined) {
      await pool.execute('UPDATE yshopadmins SET status = ? WHERE id = ?', [status, targetId]);
    } else if (is_banned !== undefined) {
      const v = is_banned ? 1 : 0;
      await pool.execute('UPDATE yshopadmins SET is_banned = ? WHERE id = ?', [v, targetId]);
    } else {
      return res.status(400).json({ success: false, message: 'Missing status or is_banned in body' });
    }

    return res.json({ success: true, data: { id: targetId } });
  } catch (err) { next(err); }
}

export async function deleteAdmin(req, res, next) {
  try {
    const targetId = req.params.adminId;
    const caller = req.admin;
    if (!caller || caller.role !== 'superadmin') return res.status(403).json({ success: false, message: 'Forbidden: superadmin required' });
    if (String(caller.id) === String(targetId)) return res.status(400).json({ success: false, message: 'Cannot delete yourself' });

    const [rows] = await pool.execute('SELECT id FROM yshopadmins WHERE id = ?', [targetId]);
    if (!rows || rows.length === 0) return res.status(404).json({ success: false, message: 'Admin not found' });

    await pool.execute('DELETE FROM yshopadmins WHERE id = ?', [targetId]);
    return res.json({ success: true, data: { id: targetId } });
  } catch (err) { next(err); }
}

export default { listAdmins, createAdmin, listUsersForAdmin, createUserUnderAdmin };
