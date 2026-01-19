import pool from '../config/database.js';
import logger from '../config/logger.js';

/**
 * User Model
 */
export class User {
  static async create(userData) {
    try {
      const { uid, email, displayName, phone, name, surname } = userData;

      // If explicit name/surname not provided, try to derive from displayName
      let firstName = name || '';
      let lastName = surname || '';
      if ((firstName == null || firstName === '') && displayName) {
        const parts = displayName.trim().split(/\s+/);
        if (parts.length === 1) {
          firstName = parts[0];
        } else if (parts.length >= 2) {
          firstName = parts.slice(0, parts.length - 1).join(' ');
          lastName = parts[parts.length - 1];
        }
      }

      const connection = await pool.getConnection();
      const [result] = await connection.execute(
        `INSERT INTO users 
         (uid, email, display_name, name, surname, phone, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, NOW())`,
        [uid, email || null, displayName || null, firstName || null, lastName || null, phone || null]
      );
      connection.release();

      return { id: result.insertId, ...userData };
    } catch (error) {
      logger.error('Error creating user:', error);
      throw error;
    }
  }

  static async findByUid(uid) {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute(
        'SELECT * FROM users WHERE uid = ?',
        [uid]
      );
      connection.release();
      return rows[0];
    } catch (error) {
      logger.error('Error finding user:', error);
      throw error;
    }
  }

  static async findByEmail(email) {
    try {
      const connection = await pool.getConnection();
      const [rows] = await connection.execute(
        'SELECT * FROM users WHERE email = ?',
        [email]
      );
      connection.release();
      return rows[0];
    } catch (error) {
      logger.error('Error finding user by email:', error);
      throw error;
    }
  }

  static async update(uid, userData) {
    try {
      const updates = [];
      const values = [];

      Object.entries(userData).forEach(([key, value]) => {
        if (value !== undefined && value !== null && key !== 'uid') {
          updates.push(`${this.camelToSnake(key)} = ?`);
          values.push(value);
        }
      });

      if (updates.length === 0) return null;

      values.push(uid);

      const connection = await pool.getConnection();
      await connection.execute(
        `UPDATE users SET ${updates.join(', ')} WHERE uid = ?`,
        values
      );
      connection.release();

      return { uid, ...userData };
    } catch (error) {
      logger.error('Error updating user:', error);
      throw error;
    }
  }

  static camelToSnake(str) {
    return str.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
  }
}

export default User;
