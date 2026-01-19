import express from 'express';
import cors from 'cors';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import dotenv from 'dotenv';
import logger from './config/logger.js';
import pool from './config/database.js';
import startFirestoreSync from './utils/firestoreSync.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';

// Routes
import productRoutes from './routes/productRoutes.js';
import storeRoutes from './routes/storeRoutes.js';
import orderRoutes from './routes/orderRoutes.js';
import userRoutes from './routes/userRoutes.js';
import cartRoutes from './routes/cartRoutes.js';
import deliveryRoutes from './routes/deliveryRoutes.js';
import adminRoutes from './routes/adminRoutes.js'; // this is yahop admin routes
import adminsMgmtRoutes from './routes/adminsRoutes.js';
import staffRoutes from './routes/staffRoutes.js';
import authRoutes from './routes/authRoutes.js';
import categoryRoutes from './routes/categoryRoutes.js'; // ✨ Categories

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security Middleware
app.use(helmet());

// CORS Configuration
app.use(
  cors({
    origin: process.env.NODE_ENV === 'production' 
      ? ['http://localhost:3000'] // Update with production domain
      : '*',
    credentials: true,
  })
);

// Body Parser
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Request logger - only log non-static requests in development
app.use((req, res, next) => {
  // Skip logging for static files and health checks
  if (!req.url.includes('/uploads/') && !req.url.includes('/health')) {
    if (process.env.NODE_ENV === 'development') {
      const authHeader = req.headers.authorization ? '[AUTH]' : '[NO-AUTH]';
      console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} ${authHeader}`);
    }
  }
  next();
});

// Compression
app.use(compression());

//  Smart caching: Admin endpoints should NOT be cached, public endpoints can be
app.use((req, res, next) => {
  if (req.method === 'GET') {
    //  CRITICAL: Admin endpoints must NOT be cached to prevent stale data
    if (req.path.includes('/admin/') || req.path.includes('/dashboard')) {
      res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else {
      // Public endpoints can use cache (5 minutes)
      res.set('Cache-Control', 'public, max-age=300');
    }
  } else {
    res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  }
  next();
});

// Rate Limiting (prevent abuse)
// Global IP-based rate limiter
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 500, // limit each IP to 500 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

//  NEW: Per-user rate limiter (prevent one user from flooding)
const userLimiter = rateLimit({
  keyGenerator: (req, res) => {
    // Use user ID if authenticated, fallback to IP
    if (req.user?.uid) return req.user.uid;
    if (req.admin?.id) return `admin_${req.admin.id}`;
    return req.ip || 'unknown';
  },
  windowMs: 1 * 60 * 1000, // 1 minute window
  max: 100, // max 100 requests per user per minute
  message: 'Too many requests from this user, please try again later.',
  standardHeaders: false,
  legacyHeaders: false,
  // Skip rate limit for health checks
  skip: (req) => req.url === '/health',
});

app.use(globalLimiter);
app.use(userLimiter);

// Static files for uploads
app.use('/uploads', express.static('uploads'));

// API Routes
app.use('/api/v1/products', productRoutes);
app.use('/api/v1/stores', storeRoutes);
app.use('/api/v1/orders', orderRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/cart', cartRoutes);
app.use('/api/v1/delivery-requests', deliveryRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/admins', adminsMgmtRoutes);
app.use('/api/v1/staff', staffRoutes);
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/stores', categoryRoutes); // ✨ Categories under stores
app.use('/api/v1/categories', categoryRoutes); // ✨ Categories direct access
app.use('/api/v1', categoryRoutes); // ✨ Products category assignment

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// 404 Handler
app.use(notFound);

// Error Handler
app.use(errorHandler);

// Start Server
const server = app.listen(PORT, async () => {
  try {
    // Test database connection
    const connection = await pool.getConnection();
    await connection.execute('SELECT 1');
    connection.release();
    
    logger.info(` Server running on http://localhost:${PORT}`);
    logger.info(` Database connected successfully`);
    // Start Firestore -> MySQL sync task (if Firebase configured)
    try {
      startFirestoreSync();
    } catch (e) {
      logger.warn('Could not start Firestore sync:', e.message);
    }
  } catch (error) {
    logger.error('❌ Failed to connect to database:', error);
    process.exit(1);
  }
});

// Graceful Shutdown
process.on('SIGINT', async () => {
  logger.info('Shutting down gracefully...');
  server.close(async () => {
    await pool.end();
    logger.info('Server closed');
    process.exit(0);
  });
});

export default app;
