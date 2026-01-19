import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';
import { auth as importedAuth, firebaseInitialized as importedFirebaseInitialized } from '../config/firebase.js';
import pool from '../config/database.js';
import logger from '../config/logger.js';

// Middleware: accepts either Firebase ID tokens or admin JWTs
export const verifyFirebaseToken = async (req, res, next) => {
  // Determine runtime auth instance only if needed.
  let runtimeAuth = null;
  try {
    // Extract token early
    const authHeader = req.headers.authorization || '';
    const token = authHeader.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'Unauthorized: No token provided' });

    // Try admin JWT first (local server auth for admin/superadmin)
    try {
      const secret = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || 'change_this_secret';
      const payload = jwt.verify(token, secret);
      req.admin = { id: payload.id, email: payload.email, role: payload.role };
      //  Also set req.user for routes that expect it (they don't care if it's admin or regular user)
      req.user = { uid: `admin_${payload.id}`, email: payload.email };
      return next();
    } catch (jwtErr) {
      // Not a valid admin JWT — fall through to Firebase verification for regular users
    }

    // If we reach here, attempt Firebase verification (only for non-admin routes/users)
    if (!importedFirebaseInitialized) {
      logger.warn('Firebase not initialized. Attempting local service account JSON initialization from middleware.');
      try {
        const fs = await import('fs');
        const path = await import('path');
        const filename = 'home-720ef-firebase-adminsdk-8yjvx-4619a2dce7.json';
        const candidates = [
          path.resolve(process.cwd(), filename),
          path.resolve(process.cwd(), 'backend', filename),
          path.resolve(process.cwd(), 'src', filename),
        ];
        let saPath = null;
        for (const c of candidates) {
          if (fs.existsSync(c)) { saPath = c; break; }
        }
        if (saPath) {
          const saContent = fs.readFileSync(saPath, 'utf8');
          const sa = JSON.parse(saContent);
          if (!admin.apps || admin.apps.length === 0) {
            admin.initializeApp({ credential: admin.credential.cert(sa) });
            logger.info('Firebase Admin initialized from local JSON (middleware) at ' + saPath);
          }
          runtimeAuth = admin.auth();
        } else {
          logger.warn('Local service account JSON not found in candidate paths; skipping local init');
        }
      } catch (initErr) {
        logger.warn('Local Firebase init from middleware failed:', initErr && initErr.message ? initErr.message : initErr);
      }
    } else {
      runtimeAuth = importedAuth;
    }

    // If still not initialized, support a dev fallback when explicitly allowed
    if (!runtimeAuth) {
      const allowDev = process.env.ALLOW_DEV_AUTH === 'true';
      if (!allowDev) {
        logger.warn('Firebase not initialized and ALLOW_DEV_AUTH != true - rejecting request');
        return res.status(401).json({ success: false, message: 'Firebase not initialized. Set ALLOW_DEV_AUTH=true to enable local dev fallback.' });
      }
      logger.warn('Firebase not initialized - allowing request without auth verification (dev mode)');
      const devUid = process.env.DEV_UID || 'dev-user-123';
      req.user = { uid: devUid, email: process.env.DEV_EMAIL || 'dev@example.com' };
      try {
        const [rows] = await pool.execute('SELECT uid FROM users WHERE uid = ?', [devUid]);
        if (rows.length === 0) {
          logger.info(`Creating dev user in MySQL (${devUid})`);
          await pool.execute('INSERT INTO users (uid, email, display_name) VALUES (?, ?, ?)', [devUid, process.env.DEV_EMAIL || 'dev@example.com', process.env.DEV_DISPLAY_NAME || 'Dev User']);
          logger.info(`Dev user ${devUid} created successfully in DB`);
        }
      } catch (dbErr) {
        logger.error('Error ensuring dev user exists in DB:', dbErr);
      }
      return next();
    }

    // Try Firebase verifyIdToken
    try {
      logger.info('Verifying Firebase token', { tokenLength: token.length, tokenStart: token.substring(0, 20) });
      const decoded = await runtimeAuth.verifyIdToken(token);
      logger.info('✅ Firebase token verified', { uid: decoded.uid, email: decoded.email });
      // Sync user to MySQL (best-effort)
      const uid = decoded.uid;
      try {
        const [rows] = await pool.execute('SELECT uid FROM users WHERE uid = ?', [uid]);
        if (rows.length === 0) {
          const displayName = decoded.name || decoded.email || 'User';
          await pool.execute('INSERT INTO users (uid, email, display_name) VALUES (?, ?, ?)', [uid, decoded.email || '', displayName]);
          logger.info(`User ${uid} synced to MySQL`);
        }
      } catch (dbErr) {
        logger.error('Database sync error in middleware:', dbErr);
      }
      req.user = { uid: decoded.uid, email: decoded.email, emailVerified: decoded.email_verified };
      return next();
    } catch (firebaseErr) {
      logger.error('❌ Token verification failed: ', firebaseErr.message);
      return res.status(401).json({ success: false, message: 'Unauthorized: Invalid token' });
    }
  } catch (outerErr) {
    logger.error('Unexpected auth middleware error:', outerErr);
    return res.status(500).json({ success: false, message: 'Internal auth error' });
  }
};

export const verifyAdminRole = async (req, res, next) => {
  try {
    if (req.admin && (req.admin.role === 'admin' || req.admin.role === 'superadmin')) return next();

    if (req.user && req.user.email) {
      try {
        const [rows] = await pool.execute('SELECT id, role FROM yshopadmins WHERE email = ?', [req.user.email]);
        if (rows && rows.length > 0) {
          req.admin = { id: rows[0].id, email: req.user.email, role: rows[0].role };
          return next();
        }
      } catch (dbErr) {
        logger.error('Error checking admin role:', dbErr);
      }
    }
    return res.status(403).json({ success: false, message: 'Forbidden: Admin role required' });
  } catch (err) {
    logger.error('verifyAdminRole error:', err);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// Backwards-compatible named exports used by routes
export const authMiddleware = verifyFirebaseToken;
export const adminMiddleware = verifyAdminRole;

export default { verifyFirebaseToken, verifyAdminRole, authMiddleware, adminMiddleware };