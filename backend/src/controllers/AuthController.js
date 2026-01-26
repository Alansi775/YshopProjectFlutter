import bcrypt from 'bcryptjs';
import pool from '../config/database.js';
import logger from '../config/logger.js';
import { generateJWT, generateVerificationToken, generateTokenExpiry } from '../utils/tokenUtils.js';
import { getEmailService } from '../utils/emailService.js';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

class AuthController {
  // POST /api/v1/auth/signup
  static async signup(req, res, next) {
    try {
      const { 
        email, password, display_name, phone,
        name, surname, national_id, address,
        latitude, longitude, building_info,
        apartment_number, delivery_instructions
      } = req.body;

      if (!email || !password || !display_name) {
        return res.status(400).json({ 
          success: false, 
          message: 'email, password, and display_name are required' 
        });
      }

      const connection = await pool.getConnection();

      // Check if user already exists
      const [existingUsers] = await connection.execute('SELECT id FROM users WHERE email = ?', [email]);
      if (existingUsers.length > 0) {
        connection.release();
        return res.status(409).json({ success: false, message: 'Email already registered' });
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 10);
      
      // Generate verification token
      const verificationToken = generateVerificationToken();
      const tokenExpires = generateTokenExpiry(24);

      // Generate unique UID for this user
      const uid = `user_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      // Insert user into database with all fields
      await connection.execute(
        `INSERT INTO users (uid, email, password_hash, display_name, phone, 
         name, surname, national_id, address, latitude, longitude,
         building_info, apartment_number, delivery_instructions,
         email_verified, verification_token, verification_token_expires) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [uid, email, passwordHash, display_name, phone,
         name || null, surname || null, national_id || null, address || null,
         latitude || null, longitude || null, building_info || null,
         apartment_number || null, delivery_instructions || null,
         0, verificationToken, tokenExpires]
      );

      connection.release();

      // Send verification email
      try {
        const emailService = await getEmailService();
        await emailService.sendVerificationEmail(email, verificationToken, display_name, 'en');
      } catch (emailError) {
        logger.warn('Failed to send verification email, but user was created:', emailError.message);
        // Don't fail the signup if email fails
      }

      return res.status(201).json({
        success: true,
        message: 'User registered successfully. Please check your email to verify your account.',
        email,
      });
    } catch (error) {
      logger.error('Error in signup:', error);
      next(error);
    }
  }

  // POST /api/v1/auth/delivery-signup
  static async deliverySignup(req, res, next) {
    try {
      const { 
        email, password, name, phone,
        nationalID, address
      } = req.body;

      if (!email || !password || !name || !phone) {
        return res.status(400).json({ 
          success: false, 
          message: 'email, password, name, and phone are required' 
        });
      }

      const connection = await pool.getConnection();

      // Check if driver/user already exists in delivery_requests or users
      const [existingDelivery] = await connection.execute('SELECT id FROM delivery_requests WHERE email = ?', [email]);
      if (existingDelivery.length > 0) {
        connection.release();
        return res.status(409).json({ success: false, message: 'Email already registered as a delivery driver' });
      }

      const [existingUsers] = await connection.execute('SELECT id FROM users WHERE email = ?', [email]);
      if (existingUsers.length > 0) {
        connection.release();
        return res.status(409).json({ success: false, message: 'Email already registered' });
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 10);
      
      // Generate unique UID
      const uid = `driver_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // Generate verification token for email verification
      const verificationToken = generateVerificationToken();
      const tokenExpires = generateTokenExpiry(24);

      // Create delivery request with verification token (pending admin approval + email verification)
      await connection.execute(
        `INSERT INTO delivery_requests (uid, email, name, phone, national_id, address, status, password_hash, verification_token, verification_token_expires, email_verified) 
         VALUES (?, ?, ?, ?, ?, ?, 'Pending', ?, ?, ?, 0)`,
        [uid, email, name, phone, nationalID || null, address || null, passwordHash, verificationToken, tokenExpires]
      );

      connection.release();

      // Send verification email with token
      try {
        const emailService = await getEmailService();
        await emailService.sendVerificationEmail(email, verificationToken, name, 'en');
      } catch (emailError) {
        logger.warn('Failed to send verification email:', emailError.message);
      }

      logger.info(`New delivery driver signup: ${email}`);

      return res.status(201).json({
        success: true,
        message: 'Your request has been sent! Please check your email to verify and wait for admin approval.',
        email,
        uid,
      });
    } catch (error) {
      logger.error('Error in deliverySignup:', error);
      next(error);
    }
  }

  // POST /api/v1/auth/verify-email
  static async verifyEmail(req, res, next) {
    try {
      const { token } = req.body;

      if (!token) {
        return res.status(400).json({ success: false, message: 'Verification token is required' });
      }

      const connection = await pool.getConnection();

      // Find user with this token
      const [users] = await connection.execute(
        `SELECT id, email FROM users 
         WHERE verification_token = ? AND verification_token_expires > NOW()`,
        [token]
      );

      if (users.length === 0) {
        connection.release();
        return res.status(400).json({ success: false, message: 'Invalid or expired verification token' });
      }

      const user = users[0];

      // Update user to mark email as verified
      await connection.execute(
        `UPDATE users 
         SET email_verified = 1, verification_token = NULL, verification_token_expires = NULL 
         WHERE id = ?`,
        [user.id]
      );

      connection.release();

      return res.json({
        success: true,
        message: 'Email verified successfully. You can now log in.',
      });
    } catch (error) {
      logger.error('Error in verifyEmail:', error);
      next(error);
    }
  }

  // GET /api/v1/auth/verify-email?token=xxx (من البريد)
  static async verifyEmailFromLink(req, res, next) {
    try {
      const { token } = req.query;

      if (!token) {
        const __filename = fileURLToPath(import.meta.url);
        const __dirname = dirname(__filename);
        const errorPath = join(__dirname, '../../public/verify-email-error.html');
        return res.status(400).sendFile(errorPath);
      }

      const connection = await pool.getConnection();

      // First try to find in users table (customers)
      const [users] = await connection.execute(
        `SELECT id, email, 'user' as type FROM users 
         WHERE verification_token = ? AND verification_token_expires > NOW()`,
        [token]
      );

      // If not found, try stores table (store owners)
      let record = null;
      let type = null;

      if (users.length > 0) {
        record = users[0];
        type = 'user';
      } else {
        const [stores] = await connection.execute(
          `SELECT id, email, 'store' as type FROM stores 
           WHERE verification_token = ? AND verification_token_expires > NOW()`,
          [token]
        );

        if (stores.length > 0) {
          record = stores[0];
          type = 'store';
        } else {
          // Try delivery_requests table (delivery drivers)
          const [deliveries] = await connection.execute(
            `SELECT id, email, uid, 'delivery' as type FROM delivery_requests 
             WHERE verification_token = ? AND verification_token_expires > NOW()`,
            [token]
          );

          if (deliveries.length > 0) {
            record = deliveries[0];
            type = 'delivery';
          }
        }
      }

      if (!record) {
        connection.release();
        const __filename = fileURLToPath(import.meta.url);
        const __dirname = dirname(__filename);
        const errorPath = join(__dirname, '../../public/verify-email-error.html');
        return res.status(400).sendFile(errorPath);
      }

      // Update the appropriate table to mark email as verified
      if (type === 'user') {
        await connection.execute(
          `UPDATE users 
           SET email_verified = 1, verification_token = NULL, verification_token_expires = NULL 
           WHERE id = ?`,
          [record.id]
        );
      } else if (type === 'store') {
        await connection.execute(
          `UPDATE stores 
           SET email_verified = 1, verification_token = NULL, verification_token_expires = NULL 
           WHERE id = ?`,
          [record.id]
        );
      } else if (type === 'delivery') {
        await connection.execute(
          `UPDATE delivery_requests 
           SET email_verified = 1, verification_token = NULL, verification_token_expires = NULL 
           WHERE id = ?`,
          [record.id]
        );
      }

      connection.release();

      // Send success page
      const __filename = fileURLToPath(import.meta.url);
      const __dirname = dirname(__filename);
      const successPath = join(__dirname, '../../public/verify-email-success.html');
      return res.status(200).sendFile(successPath);
    } catch (error) {
      logger.error('Error in verifyEmailFromLink:', error);
      const __filename = fileURLToPath(import.meta.url);
      const __dirname = dirname(__filename);
      const errorPath = join(__dirname, '../../public/verify-email-error.html');
      return res.status(500).sendFile(errorPath);
    }
  }

  // POST /api/v1/auth/login
  static async login(req, res, next) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        return res.status(400).json({ success: false, message: 'email and password are required' });
      }

      const connection = await pool.getConnection();

      // Find user
      const [users] = await connection.execute(
        `SELECT id, uid, email, password_hash, display_name, email_verified FROM users WHERE email = ?`,
        [email]
      );

      if (users.length === 0) {
        connection.release();
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
      }

      const user = users[0];

      // Check if email is verified
      if (!user.email_verified) {
        connection.release();
        return res.status(403).json({ 
          success: false, 
          message: 'Please verify your email before logging in',
          requiresVerification: true,
        });
      }

      // Verify password
      const passwordMatch = await bcrypt.compare(password, user.password_hash);
      if (!passwordMatch) {
        connection.release();
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
      }

      // Check if user is a delivery driver
      const [deliveryRequests] = await connection.execute(
        `SELECT id, status FROM delivery_requests WHERE email = ? LIMIT 1`,
        [email]
      );

      let userType = 'customer';
      let isDeliveryDriver = false;
      let driverStatus = null;

      if (deliveryRequests.length > 0) {
        isDeliveryDriver = true;
        driverStatus = deliveryRequests[0].status;

        // Check if driver is approved by admin
        if (driverStatus !== 'approved') {
          connection.release();
          
          if (driverStatus === 'rejected' || driverStatus === 'banned') {
            return res.status(403).json({
              success: false,
              message: `Your delivery driver account has been ${driverStatus} by YSHOP administration. Please contact support.`,
              accountBlocked: true,
            });
          }

          // Status is 'pending'
          return res.status(403).json({
            success: false,
            message: 'Your delivery driver account is pending admin approval. Please wait for YSHOP administration to review your application.',
            requiresApproval: true,
          });
        }

        userType = 'deliveryDriver';
      }

      connection.release();

      // Generate JWT token with UID (required for Foreign Key in cart_items)
      const token = generateJWT(user.uid, user.email, userType);

      return res.json({
        success: true,
        token,
        user: {
          id: user.id,
          uid: user.uid,
          email: user.email,
          display_name: user.display_name,
          userType: userType,
        },
      });
    } catch (error) {
      logger.error('Error in login:', error);
      next(error);
    }
  }

  // POST /api/v1/auth/delivery-login (for delivery drivers)
  static async deliveryLogin(req, res, next) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        return res.status(400).json({ success: false, message: 'email and password are required' });
      }

      const connection = await pool.getConnection();

      // Find delivery driver in delivery_requests table
      const [drivers] = await connection.execute(
        `SELECT id, uid, email, password_hash, name, status, email_verified FROM delivery_requests WHERE email = ?`,
        [email]
      );

      if (drivers.length === 0) {
        connection.release();
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
      }

      const driver = drivers[0];

      // Check if email is verified
      if (!driver.email_verified) {
        connection.release();
        return res.status(403).json({ 
          success: false, 
          message: 'Please verify your email before logging in',
          requiresVerification: true,
        });
      }

      // Check if driver is approved by admin
      if (driver.status !== 'Approved') {
        connection.release();
        
        if (driver.status === 'Rejected') {
          return res.status(403).json({
            success: false,
            message: 'Your delivery driver account has been rejected by YSHOP administration. Please contact support.',
            accountBlocked: true,
            uid: driver.uid,
          });
        }

        // Status is 'Pending'
        return res.status(403).json({
          success: false,
          message: 'Your delivery driver account is pending admin approval. Please wait for YSHOP administration to review your application.',
          requiresApproval: true,
          uid: driver.uid,  // Include UID so Frontend can use it
          email: driver.email,
          name: driver.name,
        });
      }

      // Verify password
      const passwordMatch = await bcrypt.compare(password, driver.password_hash);
      if (!passwordMatch) {
        connection.release();
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
      }

      connection.release();

      // Generate JWT token with UID (driver's uid from delivery_requests)
      const token = generateJWT(driver.uid, driver.email, 'deliveryDriver');

      return res.json({
        success: true,
        token,
        user: {
          id: driver.id,
          uid: driver.uid,
          email: driver.email,
          name: driver.name,
          userType: 'deliveryDriver',
        },
      });
    } catch (error) {
      logger.error('Error in deliveryLogin:', error);
      next(error);
    }
  }

  // GET /api/v1/auth/me (get current user profile)
  static async getProfile(req, res, next) {
    try {
      if (!req.user || !req.user.id) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const connection = await pool.getConnection();
      const userRole = req.user.role;

      // If user is a store owner, get store data
      if (userRole === 'storeOwner') {
        const [stores] = await connection.execute(
          `SELECT id, uid, email, name, phone, status, store_type, icon_url, address, latitude, longitude
           FROM stores WHERE uid = ?`,
          [req.user.id]
        );
        connection.release();

        if (stores.length === 0) {
          return res.status(404).json({ success: false, message: 'Store not found' });
        }

        return res.json({
          success: true,
          data: {
            ...stores[0],
            userType: 'storeOwner',
          },
        });
      }

      // If user is a delivery driver, get delivery_requests data
      if (userRole === 'deliveryDriver') {
        const [drivers] = await connection.execute(
          `SELECT id, uid, email, name, phone, status, national_id, address, latitude, longitude
           FROM delivery_requests WHERE uid = ?`,
          [req.user.id]
        );
        connection.release();

        if (drivers.length === 0) {
          return res.status(404).json({ success: false, message: 'Driver not found' });
        }

        return res.json({
          success: true,
          data: {
            ...drivers[0],
            userType: 'deliveryDriver',
          },
        });
      }

      // Otherwise, get regular user data
      const [users] = await connection.execute(
        `SELECT id, uid, email, display_name, phone, address, name, surname, 
                national_id, latitude, longitude, building_info, apartment_number, 
                delivery_instructions, created_at, updated_at 
         FROM users WHERE uid = ?`,
        [req.user.id]
      );

      connection.release();

      if (users.length === 0) {
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      return res.json({
        success: true,
        data: {
          ...users[0],
          userType: userRole || 'customer',
        },
      });
    } catch (error) {
      logger.error('Error in getProfile:', error);
      next(error);
    }
  }

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

      // If authenticated as regular user
      if (req.user && req.user.id) {
        const userId = req.user.id;
        const [userRows] = await connection.execute('SELECT id, password_hash FROM users WHERE id = ?', [userId]);
        if (userRows && userRows.length > 0) {
          const row = userRows[0];
          const match = await bcrypt.compare(oldPassword, row.password_hash || '');
          if (!match) {
            connection.release();
            return res.status(403).json({ success: false, message: 'Current password is incorrect' });
          }
          const hashed = await bcrypt.hash(newPassword, 10);
          await connection.execute('UPDATE users SET password_hash = ? WHERE id = ?', [hashed, row.id]);
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

  // POST /api/v1/auth/store-signup - Store Owner (Merchant) Registration
  static async storeSignup(req, res, next) {
    try {
      const { 
        email, password, phone, address,
        latitude, longitude, storeType, storeName
      } = req.body;

      // storeName is required (اسم المحل)
      if (!email || !password || !phone || !storeName) {
        return res.status(400).json({ 
          success: false, 
          message: 'email, password, phone, and storeName are required' 
        });
      }

      const connection = await pool.getConnection();

      // Check if email already exists in users or stores
      const [existingUsers] = await connection.execute(
        'SELECT id FROM users WHERE email = ?', 
        [email]
      );
      const [existingStores] = await connection.execute(
        'SELECT id FROM stores WHERE email = ?', 
        [email]
      );

      if (existingUsers.length > 0 || existingStores.length > 0) {
        connection.release();
        return res.status(409).json({ success: false, message: 'Email already registered' });
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 10);
      
      // Generate verification token
      const verificationToken = generateVerificationToken();
      const tokenExpires = generateTokenExpiry(24);

      // Generate unique UID
      const uid = `store_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      // Create store in stores table (NOT in users table)
      // Status should be 'pending' until admin approves
      await connection.execute(
        `INSERT INTO stores (uid, email, password_hash, name, phone, address, 
         latitude, longitude, store_type, status, 
         email_verified, verification_token, verification_token_expires) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [uid, email, passwordHash, storeName, phone, address,
         latitude || null, longitude || null, storeType || 'general',
         'pending', 0, verificationToken, tokenExpires]
      );

      connection.release();

      // Send verification email
      try {
        const emailService = await getEmailService();
        await emailService.sendVerificationEmail(email, verificationToken, storeName, 'en');
      } catch (emailError) {
        logger.warn('Failed to send verification email, but store was created:', emailError.message);
      }

      logger.info(`New store signup: ${email} (${storeName})`);

      return res.status(201).json({
        success: true,
        message: 'Store registered successfully. Please verify your email. After email verification, please wait for admin approval.',
        email,
        uid,
      });
    } catch (error) {
      logger.error('Error in storeSignup:', error);
      next(error);
    }
  }

  // POST /api/v1/auth/store-login - Store Owner Login
  static async storeLogin(req, res, next) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        return res.status(400).json({ success: false, message: 'email and password are required' });
      }

      const connection = await pool.getConnection();

      // Find store
      const [stores] = await connection.execute(
        `SELECT id, uid, email, password_hash, name, status, email_verified FROM stores WHERE email = ?`,
        [email]
      );

      if (stores.length === 0) {
        connection.release();
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
      }

      const store = stores[0];

      // Check if email is verified
      if (!store.email_verified) {
        connection.release();
        return res.status(403).json({ 
          success: false, 
          message: 'Please verify your email before logging in',
          requiresVerification: true,
        });
      }

      // Check if store is approved by admin
      if (store.status !== 'approved') {
        connection.release();
        
        if (store.status === 'rejected' || store.status === 'banned') {
          return res.status(403).json({
            success: false,
            message: `Your store account has been ${store.status} by YSHOP administration. Please contact support.`,
            accountBlocked: true,
          });
        }

        // Status is 'pending'
        return res.status(403).json({
          success: false,
          message: 'Your store is pending admin approval. Please wait for YSHOP administration to review your application.',
          requiresApproval: true,
        });
      }

      // Verify password
      const passwordMatch = await bcrypt.compare(password, store.password_hash);
      if (!passwordMatch) {
        connection.release();
        return res.status(401).json({ success: false, message: 'Invalid email or password' });
      }

      connection.release();

      // Generate JWT token with 'storeOwner' role (use uid for Foreign Key compatibility)
      const token = generateJWT(store.uid, store.email, 'storeOwner');

      return res.json({
        success: true,
        token,
        user: {
          id: store.id,
          uid: store.uid,
          email: store.email,
          name: store.name,
          userType: 'storeOwner',
        },
      });
    } catch (error) {
      logger.error('Error in storeLogin:', error);
      next(error);
    }
  }
}

export default AuthController;
