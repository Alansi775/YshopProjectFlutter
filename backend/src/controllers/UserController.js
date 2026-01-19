import User from '../models/User.js';
import Store from '../models/Store.js';
import logger from '../config/logger.js';
import pool from '../config/database.js';

export class UserController {
  static async getProfile(req, res, next) {
    try {
      const uid = req.user.uid;

      const user = await User.findByUid(uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found',
        });
      }

      res.json({
        success: true,
        data: user,
      });
    } catch (error) {
      logger.error('Error in getProfile:', error);
      next(error);
    }
  }

  static async getUserStore(req, res, next) {
    try {
      //  PRIORITY: Get uid from query parameter FIRST (for store owner switches)
      // Then fall back to Firebase token
      let uid = req.query.uid || req.body.uid || req.user?.uid;
      
      if (!uid) {
        return res.status(400).json({
          success: false,
          message: 'User UID is required',
        });
      }

      logger.debug(`getUserStore: Looking for store with owner_uid=${uid}`);
      let store = await Store.findByOwnerUid(uid);

      // If no store found by uid, try to find by email (covers cases where owner UID mismatch)
      if (!store && req.user && req.user.email) {
        logger.debug(`getUserStore: No store found by UID, trying email: ${req.user.email}`);
        store = await Store.findByOwnerEmail(req.user.email);
      }

      if (!store) {
        return res.status(404).json({
          success: false,
          message: 'No store found for this user',
        });
      }

      res.json({
        success: true,
        data: store,
      });
    } catch (error) {
      logger.error('Error in getUserStore:', error);
      next(error);
    }
  }

  static async updateProfile(req, res, next) {
    try {
      const uid = req.user.uid;
      const {
        displayName,
        phone,
        address,
        latitude,
        longitude,
        nationalId,
        surname,
        buildingInfo,
        apartmentNumber,
        deliveryInstructions,
      } = req.body;

      const user = await User.update(uid, {
        displayName,
        surname,
        phone,
        address,
        latitude,
        longitude,
        nationalId,
        buildingInfo,
        apartmentNumber,
        deliveryInstructions,
      });

      res.json({
        success: true,
        data: user,
      });
    } catch (error) {
      logger.error('Error in updateProfile:', error);
      next(error);
    }
  }

  static async createIfNotExists(req, res, next) {
    try {
      const { uid, email, displayName } = req.body;

      logger.info('createIfNotExists called with:', { uid, email, displayName });

      if (!uid || !email) {
        return res.status(400).json({
          success: false,
          message: 'uid and email are required',
        });
      }

      let user = await User.findByUid(uid);
      
      logger.info('After findByUid:', { user, uid });

      if (!user) {
        // Also check if user exists by email to avoid duplicate entry errors
        let userByEmail = await User.findByEmail(email);
        logger.info('After findByEmail:', { userByEmail, email });
        
        if (userByEmail) {
          user = userByEmail;
        } else {
          try {
            // Derive name and surname from displayName when possible
            let name = '';
            let surname = '';
            if (displayName) {
              const parts = displayName.trim().split(/\s+/);
              if (parts.length === 1) {
                name = parts[0];
              } else if (parts.length >= 2) {
                name = parts.slice(0, parts.length - 1).join(' ');
                surname = parts[parts.length - 1];
              }
            }

            user = await User.create({
              uid,
              email: email || null,
              displayName: displayName || null,
              name: name || null,
              surname: surname || null,
            });
            logger.info('User created successfully:', { user });
          } catch (createError) {
            logger.error('Error creating user:', { createError: createError.code, message: createError.message });
            // If duplicate entry error, try to find by email
            if (createError.code === 'ER_DUP_ENTRY') {
              user = await User.findByEmail(email) || { uid, email, displayName };
            } else {
              throw createError;
            }
          }
        }
      }

      res.json({
        success: true,
        data: user,
      });
    } catch (error) {
      logger.error('Error in createIfNotExists:', error);
      next(error);
    }
  }

  static async listAll(req, res, next) {
    try {
      // Include status and is_banned so the admin UI can reflect ban state immediately
      const [rows] = await pool.execute('SELECT id, email, first_name, last_name, role, admin_id, status, is_banned, created_at FROM yshopusers ORDER BY id DESC');
      return res.json({ success: true, data: rows });
    } catch (error) {
      logger.error('Error listing all users:', error);
      next(error);
    }
  }

  static async updateUserStatusAdmin(req, res, next) {
    try {
      const userId = req.params.userId;
      const { status, is_banned } = req.body || {};

      let rows;
      try {
        const result = await pool.execute('SELECT id, admin_id, status, is_banned FROM yshopusers WHERE id = ?', [userId]);
        rows = result[0];
      } catch (err) {
        if (err && err.code === 'ER_BAD_FIELD_ERROR') {
          const result = await pool.execute('SELECT id, admin_id FROM yshopusers WHERE id = ?', [userId]);
          rows = result[0];
          req._missingUserStatusColumn = true;
        } else {
          throw err;
        }
      }
      if (!rows || rows.length === 0) return res.status(404).json({ success: false, message: 'User not found' });
      const userRow = rows[0];

      // permission: superadmin can modify any user; admin can only modify users belonging to their admin_id
      const caller = req.admin;
      if (!caller) return res.status(401).json({ success: false, message: 'Unauthorized' });
      if (caller.role !== 'superadmin' && userRow.admin_id != caller.id) {
        return res.status(403).json({ success: false, message: 'Forbidden: cannot modify this user' });
      }

      if (req._missingUserStatusColumn) {
        if (is_banned === undefined) {
          return res.status(400).json({ success: false, message: 'Database missing status column; provide is_banned' });
        }
        const v = is_banned ? 1 : 0;
        await pool.execute('UPDATE yshopusers SET is_banned = ? WHERE id = ?', [v, userId]);
      } else {
        if (status !== undefined) {
          await pool.execute('UPDATE yshopusers SET status = ? WHERE id = ?', [status, userId]);
        } else if (is_banned !== undefined) {
          const v = is_banned ? 1 : 0;
          await pool.execute('UPDATE yshopusers SET is_banned = ? WHERE id = ?', [v, userId]);
        } else {
          return res.status(400).json({ success: false, message: 'Missing status or is_banned in body' });
        }
      }

      return res.json({ success: true, data: { id: userId } });
    } catch (error) {
      logger.error('Error updating user status (admin):', error);
      next(error);
    }
  }

  static async deleteUserAdmin(req, res, next) {
    try {
      const userId = req.params.userId;

      const [rows] = await pool.execute('SELECT id, admin_id FROM yshopusers WHERE id = ?', [userId]);
      if (!rows || rows.length === 0) return res.status(404).json({ success: false, message: 'User not found' });
      const userRow = rows[0];

      const caller = req.admin;
      if (!caller) return res.status(401).json({ success: false, message: 'Unauthorized' });
      if (caller.role !== 'superadmin' && userRow.admin_id != caller.id) {
        return res.status(403).json({ success: false, message: 'Forbidden: cannot delete this user' });
      }

      await pool.execute('DELETE FROM yshopusers WHERE id = ?', [userId]);
      return res.json({ success: true, data: { id: userId } });
    } catch (error) {
      logger.error('Error deleting user (admin):', error);
      next(error);
    }
  }
}

export default UserController;
