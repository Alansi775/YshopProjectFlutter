// routes/delivery.routes.js
// ═══════════════════════════════════════════════════════════════════════════════
// 🚚 DELIVERY ROUTES
// ═══════════════════════════════════════════════════════════════════════════════

import { Router } from 'express';
import DeliveryController from '../controllers/DeliveryController.js';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();

// ─────────────────────────────────────────────────────────────────────────────
// 📝 DRIVER PROFILE
// ─────────────────────────────────────────────────────────────────────────────

// Create delivery request (signup)
router.post('/', authMiddleware, DeliveryController.create);

// Get own profile
router.get('/me', authMiddleware, DeliveryController.me);

// Update location
router.put('/location', authMiddleware, DeliveryController.updateLocation);

// Update working status
router.put('/working', authMiddleware, DeliveryController.updateWorking);

// ─────────────────────────────────────────────────────────────────────────────
// 🎁 ORDER OFFERS
// ─────────────────────────────────────────────────────────────────────────────

// Get order offer for this driver
router.get('/offer', authMiddleware, DeliveryController.getOrderOffer);

// Accept order offer
router.post('/offer/accept', authMiddleware, DeliveryController.acceptOffer);

// Skip order offer
router.post('/offer/skip', authMiddleware, DeliveryController.skipOffer);

// Get skipped orders (for reclaim button)
router.get('/skipped-orders', authMiddleware, DeliveryController.getSkippedOrders);

// Reclaim a skipped order
router.post('/reclaim', authMiddleware, DeliveryController.reclaimOrder);

// Get active order
router.get('/active-order', authMiddleware, DeliveryController.getActiveOrder);

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER LIFECYCLE
// ─────────────────────────────────────────────────────────────────────────────

// Mark order as picked up (after QR scan)
router.post('/orders/:orderId/pickup', authMiddleware, DeliveryController.pickupOrder);

// Update driver location on order
router.put('/orders/:orderId/location', authMiddleware, DeliveryController.updateOrderLocation);

// Mark order as delivered
router.post('/orders/:orderId/delivered', authMiddleware, DeliveryController.markDelivered);

// ─────────────────────────────────────────────────────────────────────────────
// 📊 HISTORY & STATS
// ─────────────────────────────────────────────────────────────────────────────

// Get delivery history
router.get('/history', authMiddleware, DeliveryController.getDeliveryHistory);

// Get driver stats
router.get('/stats', authMiddleware, DeliveryController.getDriverStats);

// ─────────────────────────────────────────────────────────────────────────────
// 👨‍💼 ADMIN ROUTES
// ─────────────────────────────────────────────────────────────────────────────

// List pending requests
router.get('/pending', authMiddleware, DeliveryController.listPending);

// List approved drivers
router.get('/approved', authMiddleware, DeliveryController.listApproved);

// List active (online) drivers
router.get('/active', authMiddleware, DeliveryController.listActive);

// Get all driver locations (for map)
router.get('/locations', authMiddleware, DeliveryController.getAllDriverLocations);

// Approve driver
router.post('/:id/approve', authMiddleware, DeliveryController.approve);

// Reject driver
router.post('/:id/reject', authMiddleware, DeliveryController.reject);

// Set back to pending
router.post('/:id/pending', authMiddleware, DeliveryController.setPending);

// Delete driver
router.delete('/:id', authMiddleware, DeliveryController.delete);

// ─────────────────────────────────────────────────────────────────────────────
// 🔧 LEGACY / MISC
// ─────────────────────────────────────────────────────────────────────────────

// Find nearby orders
router.post('/nearby', authMiddleware, DeliveryController.nearby);

export default router;