import { Router } from 'express';
import OrderController from '../controllers/OrderController.js';
import { verifyFirebaseToken } from '../middleware/auth.js';

const router = Router();

// All order routes require authentication
router.use(verifyFirebaseToken);

router.post('/', OrderController.create);
router.get('/admin', OrderController.getAdminOrders);
router.get('/store/:storeId', OrderController.getStoreOrders);
router.get('/user/orders', OrderController.getUserOrders);
router.get('/:id', OrderController.getById);
router.put('/:id/status', OrderController.updateStatus);
router.post('/:id/assign', OrderController.assignToDriver);
router.post('/:id/picked-up', OrderController.pickedUp);
router.post('/:id/mark-delivered', OrderController.markDelivered);

export default router;
