import bcrypt from 'bcryptjs';
import pool from '../config/database.js';
import logger from '../config/logger.js';

class AuthController {
  // PUT /api/v1/auth/me/password
  static async changeMyPassword(req, res, next) {
    try {
      const body = req.body || {};
      const { oldPassword, newPassword } = body;
      if (!oldPassword || !newPassword) return res.status(400).json({ success: false, message: 'oldPassword and newPassword required' });

      const connection = await pool.getConnection();

      // If request authenticated as admin via admin JWT
      if (req.admin && req.admin.id) {
        const adminId = req.admin.id;
        const [adminRows] = await connection.execute('SELECT id, password_hash FROM yshopadmins WHERE id = ?', [adminId]);
        if (adminRows && adminRows.length > 0) {
          const row = adminRows[0];
          const match = await bcrypt.compare(oldPassword, row.password_hash || '');
          if (!match) {
            connection.release();
            return res.status(403).json({ success: false, message: 'Current password is incorrect' });
          }
          const hashed = await bcrypt.hash(newPassword, 10);
          await connection.execute('UPDATE yshopadmins SET password_hash = ? WHERE id = ?', [hashed, row.id]);
          connection.release();
          return res.json({ success: true });
        }
        connection.release();
        return res.status(404).json({ success: false, message: 'Admin not found' });
      }

      // If authenticated via Firebase token (req.user), lookup by email in yshopusers
      if (req.user && req.user.email) {
        const email = req.user.email;
        const [userRows] = await connection.execute('SELECT id, password_hash FROM yshopusers WHERE email = ?', [email]);
        if (userRows && userRows.length > 0) {
          const row = userRows[0];
          const match = await bcrypt.compare(oldPassword, row.password_hash || '');
          if (!match) {
            connection.release();
            return res.status(403).json({ success: false, message: 'Current password is incorrect' });
          }
          const hashed = await bcrypt.hash(newPassword, 10);
          await connection.execute('UPDATE yshopusers SET password_hash = ? WHERE id = ?', [hashed, row.id]);
          connection.release();
          return res.json({ success: true });
        }
        connection.release();
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      connection.release();
      return res.status(401).json({ success: false, message: 'Unauthenticated' });
    } catch (error) {
      logger.error('Error changing password', error);
      next(error);
    }
  }
}

export default AuthController;
