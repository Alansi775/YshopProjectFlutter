import { Router } from 'express';
import UserController from '../controllers/UserController.js';
import { verifyFirebaseToken, verifyAdminRole } from '../middleware/auth.js';

const router = Router();

// Get profile (requires auth)
router.get('/', verifyFirebaseToken, verifyAdminRole, UserController.listAll);
router.get('/profile', verifyFirebaseToken, UserController.getProfile);

// Get user's store (requires auth)
router.get('/store', verifyFirebaseToken, UserController.getUserStore);

// Update profile (requires auth)
router.put('/profile', verifyFirebaseToken, UserController.updateProfile);

// Admin-scoped: update user status (ban/approve)
router.put('/admin/:userId/status', verifyFirebaseToken, verifyAdminRole, UserController.updateUserStatusAdmin);

// Admin-scoped: delete user (also expose generic delete)
router.delete('/admin/:userId', verifyFirebaseToken, verifyAdminRole, UserController.deleteUserAdmin);
router.delete('/:userId', verifyFirebaseToken, verifyAdminRole, UserController.deleteUserAdmin);

// Create user if not exists (called after Firebase signup)
router.post('/sync', UserController.createIfNotExists);

export default router;
