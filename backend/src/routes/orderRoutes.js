import { Router } from 'express';
import OrderController from '../controllers/OrderController.js';
import { verifyFirebaseToken, verifyAdminToken, verifyToken } from '../middleware/auth.js';

const router = Router();

// Admin route - requires admin token
router.get('/admin', verifyAdminToken, OrderController.getAdminOrders);

// Get order by ID - accepts both admin and firebase tokens
router.get('/:id', verifyToken, OrderController.getById);

// All other order routes require firebase authentication
router.use(verifyFirebaseToken);

router.post('/', OrderController.create);
router.get('/store/:storeId', OrderController.getStoreOrders);
router.get('/user/orders', OrderController.getUserOrders);
router.put('/:id/status', OrderController.updateStatus);
router.post('/:id/assign', OrderController.assignToDriver);
router.post('/:id/picked-up', OrderController.pickedUp);
router.post('/:id/mark-delivered', OrderController.markDelivered);

export default router;
