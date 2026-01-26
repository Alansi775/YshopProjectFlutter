import { Router } from 'express';
import Cart from '../models/Cart.js';
import { verifyFirebaseToken } from '../middleware/auth.js';
import logger from '../config/logger.js';

const router = Router();

// All cart routes require authentication
router.use(verifyFirebaseToken);

// Get user cart
router.get('/', async (req, res, next) => {
  try {
    const userId = req.user?.id;
    logger.info('Get cart request', { userId, hasUser: !!req.user, userKeys: Object.keys(req.user || {}) });
    
    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized: No user ID' });
    }
    
    // 🔥 CRITICAL: Disable HTTP caching for real-time cart data
    res.set({
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    });
    
    const cartItems = await Cart.getCart(userId);
    logger.info('Get cart result', { userId, returned: (cartItems || []).length });

    res.json({
      success: true,
      data: cartItems,
    });
  } catch (error) {
    logger.error('Error getting cart:', error);
    next(error);
  }
});

// Add item to cart
router.post('/add', async (req, res, next) => {
  try {
    const userId = req.user.id;  // Now contains uid (not numeric id)
    const { productId, quantity } = req.body;
    logger.info(`Add to cart request received`, { userId, body: req.body });

    if (!productId || !quantity) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields',
      });
    }

    await Cart.addItem(userId, productId, quantity);

    res.json({
      success: true,
      message: 'Item added to cart',
    });
  } catch (error) {
    logger.error('Error adding to cart:', error);
    next(error);
  }
});

// Update cart item quantity
router.put('/item/:itemId', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { itemId } = req.params;
    const { quantity } = req.body;

    if (quantity === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Quantity is required',
      });
    }

    await Cart.updateQuantity(userId, itemId, quantity);

    res.json({
      success: true,
      message: 'Cart item updated',
    });
  } catch (error) {
    logger.error('Error updating cart item:', error);
    next(error);
  }
});

// Remove item from cart
router.delete('/item/:itemId', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { itemId } = req.params;
    
    logger.info('Delete cart item request', { userId, itemId });
    await Cart.removeItem(userId, itemId);
    logger.info('Delete cart item SUCCESS', { userId, itemId });

    res.json({
      success: true,
      message: 'Item removed from cart',
    });
  } catch (error) {
    logger.error('Error removing from cart:', error);
    next(error);
  }
});

// Clear cart
router.delete('/', async (req, res, next) => {
  try {
    const userId = req.user.id;

    await Cart.clearCart(userId);

    res.json({
      success: true,
      message: 'Cart cleared',
    });
  } catch (error) {
    logger.error('Error clearing cart:', error);
    next(error);
  }
});

export default router;
